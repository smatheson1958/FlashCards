//
//  SegmentationModuleProgressService.swift
//  FlashCards
//
//  Module-local segmentation progress, journey pair completion, error fallbacks (8.3), and secure rule (8.4).
//  Does not change global deck lock/unlock.
//

import Foundation
import SwiftData

enum SegmentationModuleProgressService {

    enum JourneyErrorDirective: Equatable {
        case none
        /// First error on the pair: repeat the same two words soon (prepended in the journey UI).
        case repeatCurrentPairImmediately(word0: String, word1: String, segments0: [String], segments1: [String])
        /// Second error: reopen the previous visit pair when possible.
        case reopenPreviousVisitPair(previousVisit: Int, word0: String, word1: String, segments0: [String], segments1: [String])
    }

    static func deleteAll(context: ModelContext) {
        let p1 = FetchDescriptor<SegmentationSoundModuleProgress>()
        (try? context.fetch(p1))?.forEach { context.delete($0) }
        let p2 = FetchDescriptor<SegmentationProgressEvent>()
        (try? context.fetch(p2))?.forEach { context.delete($0) }
        try? context.save()
    }

    static func fetchModuleProgress(soundOrderIndex: Int, context: ModelContext) -> SegmentationSoundModuleProgress? {
        let idx = soundOrderIndex
        let descriptor = FetchDescriptor<SegmentationSoundModuleProgress>(
            predicate: #Predicate { $0.soundOrderIndex == idx }
        )
        return try? context.fetch(descriptor).first
    }

    @discardableResult
    static func findOrCreateModuleProgress(soundOrderIndex: Int, context: ModelContext) -> SegmentationSoundModuleProgress {
        if let existing = fetchModuleProgress(soundOrderIndex: soundOrderIndex, context: context) {
            syncActiveVisit(with: existing)
            return existing
        }
        let row = SegmentationSoundModuleProgress(soundOrderIndex: soundOrderIndex)
        syncActiveVisit(with: row)
        context.insert(row)
        return row
    }

    /// First incomplete visit (1…5), or `nil` if all five passed.
    static func firstIncompleteVisit(mask: Int) -> Int? {
        for v in 1...5 where (mask & (1 << (v - 1))) == 0 {
            return v
        }
        return nil
    }

    static func pairWords(soundOrderIndex: Int, visitIndex: Int) -> (String, String)? {
        let pairs = SegmentationJourneyLoader.fiveVisitWordPairs(soundOrderIndex: soundOrderIndex)
        return pairs.first { $0.visitIndex == visitIndex }.map { ($0.word0, $0.word1) }
    }

    static func recordSoundAttendedOncePerAppSession(
        soundOrderIndex: Int,
        sessionRecordedSounds: inout Set<Int>,
        context: ModelContext
    ) {
        guard !sessionRecordedSounds.contains(soundOrderIndex) else { return }
        sessionRecordedSounds.insert(soundOrderIndex)
        insertEvent(
            soundOrderIndex: soundOrderIndex,
            wordKey: "",
            visitIndex: 0,
            kind: .soundAttended,
            context: context
        )
    }

    static func recordWordPresented(
        soundOrderIndex: Int,
        word: String,
        visitIndex: Int,
        sessionRecordedSounds: inout Set<Int>,
        context: ModelContext
    ) {
        recordSoundAttendedOncePerAppSession(soundOrderIndex: soundOrderIndex, sessionRecordedSounds: &sessionRecordedSounds, context: context)
        let key = ModeWordProgressService.normalizedWordKey(word)
        insertEvent(soundOrderIndex: soundOrderIndex, wordKey: key, visitIndex: visitIndex, kind: .wordPresented, context: context)
    }

    /// Records a successful segmentation completion inside the journey for `visitIndex` (1…5).
    static func recordJourneyWordSuccess(
        soundOrderIndex: Int,
        word: String,
        visitIndex: Int,
        context: ModelContext
    ) {
        let row = findOrCreateModuleProgress(soundOrderIndex: soundOrderIndex, context: context)
        syncActiveVisit(with: row)
        guard visitIndex == row.activeVisitIndexForPair else { return }
        guard let (w0, w1) = pairWords(soundOrderIndex: soundOrderIndex, visitIndex: visitIndex) else { return }

        let key = ModeWordProgressService.normalizedWordKey(word)
        guard key == w0 || key == w1 else { return }
        if key == w0, row.pairSlot0Passed { return }
        if key == w1, row.pairSlot1Passed { return }

        if key == w0 {
            row.pairSlot0Passed = true
        } else {
            row.pairSlot1Passed = true
        }

        row.lastActivityAt = Date()
        appendRecentOutcome("1", row: row)
        row.lifetimeJourneyCorrectCount += 1
        mergeDistinctSuccess(key: key, row: row)
        recomputeSegmentationSecure(row: row)

        insertEvent(soundOrderIndex: soundOrderIndex, wordKey: key, visitIndex: visitIndex, kind: .wordSuccess, context: context)

        if row.pairSlot0Passed, row.pairSlot1Passed {
            row.visitsPassedMask |= 1 << (visitIndex - 1)
            row.pairSlot0Passed = false
            row.pairSlot1Passed = false
            row.errorsOnCurrentPairCycle = 0
            syncActiveVisit(with: row)
        }

        try? context.save()
    }

    @discardableResult
    static func recordJourneyWordError(
        soundOrderIndex: Int,
        word: String,
        visitIndex: Int,
        context: ModelContext
    ) -> JourneyErrorDirective {
        let row = findOrCreateModuleProgress(soundOrderIndex: soundOrderIndex, context: context)
        syncActiveVisit(with: row)
        guard visitIndex == row.activeVisitIndexForPair else { return .none }
        guard let (w0, w1) = pairWords(soundOrderIndex: soundOrderIndex, visitIndex: visitIndex) else { return .none }

        row.errorsOnCurrentPairCycle += 1
        row.lastActivityAt = Date()
        appendRecentOutcome("0", row: row)
        row.lifetimeJourneyIncorrectCount += 1
        recomputeSegmentationSecure(row: row)

        let key = ModeWordProgressService.normalizedWordKey(word)
        insertEvent(soundOrderIndex: soundOrderIndex, wordKey: key, visitIndex: visitIndex, kind: .wordError, context: context)

        let e = row.errorsOnCurrentPairCycle
        var directive: JourneyErrorDirective = .none

        if e == 1 {
            let s0 = SegmentationDataSource.resolvedSegments(forWord: w0, soundOrderIndex: soundOrderIndex)
            let s1 = SegmentationDataSource.resolvedSegments(forWord: w1, soundOrderIndex: soundOrderIndex)
            directive = .repeatCurrentPairImmediately(word0: w0, word1: w1, segments0: s0, segments1: s1)
        } else if e == 2 {
            if visitIndex > 1, let (pw0, pw1) = pairWords(soundOrderIndex: soundOrderIndex, visitIndex: visitIndex - 1) {
                row.visitsPassedMask &= ~(1 << (visitIndex - 2))
                row.activeVisitIndexForPair = visitIndex - 1
                row.pairSlot0Passed = false
                row.pairSlot1Passed = false
                row.errorsOnCurrentPairCycle = 0
                let ps0 = SegmentationDataSource.resolvedSegments(forWord: pw0, soundOrderIndex: soundOrderIndex)
                let ps1 = SegmentationDataSource.resolvedSegments(forWord: pw1, soundOrderIndex: soundOrderIndex)
                directive = .reopenPreviousVisitPair(
                    previousVisit: visitIndex - 1,
                    word0: pw0,
                    word1: pw1,
                    segments0: ps0,
                    segments1: ps1
                )
            } else if let (cw0, cw1) = pairWords(soundOrderIndex: soundOrderIndex, visitIndex: visitIndex) {
                let s0 = SegmentationDataSource.resolvedSegments(forWord: cw0, soundOrderIndex: soundOrderIndex)
                let s1 = SegmentationDataSource.resolvedSegments(forWord: cw1, soundOrderIndex: soundOrderIndex)
                directive = .repeatCurrentPairImmediately(word0: cw0, word1: cw1, segments0: s0, segments1: s1)
            }
        } else {
            row.isFragile = true
            if let (cw0, cw1) = pairWords(soundOrderIndex: soundOrderIndex, visitIndex: visitIndex) {
                let s0 = SegmentationDataSource.resolvedSegments(forWord: cw0, soundOrderIndex: soundOrderIndex)
                let s1 = SegmentationDataSource.resolvedSegments(forWord: cw1, soundOrderIndex: soundOrderIndex)
                directive = .repeatCurrentPairImmediately(word0: cw0, word1: cw1, segments0: s0, segments1: s1)
            }
        }

        try? context.save()
        return directive
    }

    // MARK: - Private

    private static func syncActiveVisit(with row: SegmentationSoundModuleProgress) {
        if let first = firstIncompleteVisit(mask: row.visitsPassedMask) {
            if row.activeVisitIndexForPair != first {
                row.activeVisitIndexForPair = first
                row.pairSlot0Passed = false
                row.pairSlot1Passed = false
                row.errorsOnCurrentPairCycle = 0
            }
        } else {
            row.activeVisitIndexForPair = 5
        }
    }

    private static func appendRecentOutcome(_ ch: String, row: SegmentationSoundModuleProgress) {
        var s = row.recentOutcomeChars + ch
        let cap = FlashCardsConstants.SegmentationJourneySecure.maxRecentOutcomeChars
        if s.count > cap {
            s = String(s.suffix(cap))
        }
        row.recentOutcomeChars = s
    }

    private static func mergeDistinctSuccess(key: String, row: SegmentationSoundModuleProgress) {
        var parts = row.distinctSuccessWordKeysCSV.split(separator: ",").map(String.init).filter { !$0.isEmpty }
        if !parts.contains(key) {
            parts.append(key)
        }
        row.distinctSuccessWordKeysCSV = parts.joined(separator: ",")
    }

    private static func recomputeSegmentationSecure(row: SegmentationSoundModuleProgress) {
        let parts = row.distinctSuccessWordKeysCSV.split(separator: ",").map(String.init).filter { !$0.isEmpty }
        let distinct = Set(parts).count
        let minS = FlashCardsConstants.SegmentationJourneySecure.minSuccessCount
        let minW = FlashCardsConstants.SegmentationJourneySecure.minDistinctWords
        guard row.lifetimeJourneyCorrectCount >= minS, distinct >= minW else {
            row.isSegmentationSecure = false
            return
        }
        let window = FlashCardsConstants.SegmentationJourneySecure.recentWindowSize
        let tail = String(row.recentOutcomeChars.suffix(window))
        guard !tail.isEmpty else {
            row.isSegmentationSecure = false
            return
        }
        let ones = tail.filter { $0 == "1" }.count
        let acc = Double(ones) / Double(tail.count)
        row.isSegmentationSecure = acc >= FlashCardsConstants.SegmentationJourneySecure.minRecentAccuracy
    }

    private static func insertEvent(
        soundOrderIndex: Int,
        wordKey: String,
        visitIndex: Int,
        kind: SegmentationProgressEventKind,
        context: ModelContext
    ) {
        let ev = SegmentationProgressEvent(
            soundOrderIndex: soundOrderIndex,
            wordKey: wordKey,
            visitIndex: visitIndex,
            kind: kind
        )
        context.insert(ev)
    }

    // MARK: - Journey queue (unlocked sounds × visit order)

    static func nextJourneyStep(workingSounds: [CardProgress], context: ModelContext) -> SegmentationJourneyStep? {
        let sorted = workingSounds.sorted { $0.orderIndex < $1.orderIndex }
        for card in sorted {
            let row = findOrCreateModuleProgress(soundOrderIndex: card.orderIndex, context: context)
            guard let visit = firstIncompleteVisit(mask: row.visitsPassedMask) else { continue }
            guard let (w0, w1) = pairWords(soundOrderIndex: card.orderIndex, visitIndex: visit) else { continue }
            let s0 = SegmentationDataSource.resolvedSegments(forWord: w0, soundOrderIndex: card.orderIndex)
            let s1 = SegmentationDataSource.resolvedSegments(forWord: w1, soundOrderIndex: card.orderIndex)
            autoPassSegmentationSlotsIfEmpty(
                row: row,
                visitIndex: visit,
                segments0: s0,
                segments1: s1,
                context: context
            )
            let k0 = ModeWordProgressService.normalizedWordKey(w0)
            let k1 = ModeWordProgressService.normalizedWordKey(w1)
            if !row.pairSlot0Passed {
                if !s0.isEmpty {
                    return SegmentationJourneyStep(
                        id: "\(card.orderIndex)|\(visit)|\(k0)",
                        soundOrderIndex: card.orderIndex,
                        visitIndex: visit,
                        word: w0,
                        segments: s0
                    )
                }
            }
            if !row.pairSlot1Passed {
                if !s1.isEmpty {
                    return SegmentationJourneyStep(
                        id: "\(card.orderIndex)|\(visit)|\(k1)",
                        soundOrderIndex: card.orderIndex,
                        visitIndex: visit,
                        word: w1,
                        segments: s1
                    )
                }
            }
        }
        return nil
    }

    /// Builds two journey steps for a pair (used when inserting repeats after errors).
    static func journeyStepsForPair(
        soundOrderIndex: Int,
        visitIndex: Int,
        word0: String,
        word1: String,
        segments0: [String],
        segments1: [String]
    ) -> [SegmentationJourneyStep] {
        let a = journeyStep(soundOrderIndex: soundOrderIndex, visitIndex: visitIndex, word: word0, segments: segments0)
        let b = journeyStep(soundOrderIndex: soundOrderIndex, visitIndex: visitIndex, word: word1, segments: segments1)
        return [a, b]
    }

    /// If bundled segmentation data is missing for a slot, treat it as satisfied so visit pairs cannot stall.
    private static func autoPassSegmentationSlotsIfEmpty(
        row: SegmentationSoundModuleProgress,
        visitIndex: Int,
        segments0: [String],
        segments1: [String],
        context: ModelContext
    ) {
        guard visitIndex == row.activeVisitIndexForPair else { return }
        var changed = false
        if !row.pairSlot0Passed, segments0.isEmpty {
            row.pairSlot0Passed = true
            changed = true
        }
        if !row.pairSlot1Passed, segments1.isEmpty, row.pairSlot0Passed {
            row.pairSlot1Passed = true
            changed = true
        }
        if row.pairSlot0Passed, row.pairSlot1Passed {
            row.visitsPassedMask |= 1 << (visitIndex - 1)
            row.pairSlot0Passed = false
            row.pairSlot1Passed = false
            row.errorsOnCurrentPairCycle = 0
            syncActiveVisit(with: row)
            changed = true
        }
        if changed { try? context.save() }
    }

    private static func journeyStep(
        soundOrderIndex: Int,
        visitIndex: Int,
        word: String,
        segments: [String]
    ) -> SegmentationJourneyStep {
        let w = ModeWordProgressService.normalizedWordKey(word)
        return SegmentationJourneyStep(
            id: "\(soundOrderIndex)|\(visitIndex)|\(w)",
            soundOrderIndex: soundOrderIndex,
            visitIndex: visitIndex,
            word: word,
            segments: segments
        )
    }
}
