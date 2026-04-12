//
//  ModeWordProgressService.swift
//  FlashCards
//

import Foundation
import SwiftData

enum ModeWordProgressService {
    static func progressID(soundOrderIndex: Int, mode: PhonicsModeExerciseKind, wordKey: String) -> String {
        "\(soundOrderIndex)|\(mode.rawValue)|\(wordKey)"
    }

    static func normalizedWordKey(_ word: String) -> String {
        ConstructionDataSource.normalizedWordKey(word)
    }

    static func fetch(
        soundOrderIndex: Int,
        mode: PhonicsModeExerciseKind,
        wordKey: String,
        context: ModelContext
    ) -> ModeWordProgress? {
        let id = progressID(soundOrderIndex: soundOrderIndex, mode: mode, wordKey: wordKey)
        let descriptor = FetchDescriptor<ModeWordProgress>(
            predicate: #Predicate { $0.progressID == id }
        )
        return try? context.fetch(descriptor).first
    }

    @discardableResult
    static func findOrCreate(
        soundOrderIndex: Int,
        mode: PhonicsModeExerciseKind,
        word: String,
        context: ModelContext
    ) -> ModeWordProgress {
        let wordKey = normalizedWordKey(word)
        let id = progressID(soundOrderIndex: soundOrderIndex, mode: mode, wordKey: wordKey)
        if let existing = fetch(soundOrderIndex: soundOrderIndex, mode: mode, wordKey: wordKey, context: context) {
            return existing
        }
        let row = ModeWordProgress(progressID: id, soundOrderIndex: soundOrderIndex, kind: mode, wordKey: wordKey, correctCountTowardMastery: 0)
        context.insert(row)
        return row
    }

    /// One successful Construction build or Segmentation practice session.
    static func recordSuccessfulAttempt(
        soundOrderIndex: Int,
        mode: PhonicsModeExerciseKind,
        word: String,
        context: ModelContext
    ) {
        let row = findOrCreate(soundOrderIndex: soundOrderIndex, mode: mode, word: word, context: context)
        let cap = FlashCardsConstants.modeExerciseWordMasteryCount
        row.correctCountTowardMastery = min(cap, row.correctCountTowardMastery + 1)
        try? context.save()
    }

    /// Wrong attempt on a reminder session: back to zero; then requires five successes again.
    static func resetFromReminderWrong(
        soundOrderIndex: Int,
        mode: PhonicsModeExerciseKind,
        word: String,
        context: ModelContext
    ) {
        let wordKey = normalizedWordKey(word)
        guard let row = fetch(soundOrderIndex: soundOrderIndex, mode: mode, wordKey: wordKey, context: context) else { return }
        row.correctCountTowardMastery = 0
        try? context.save()
    }

    static func deleteAll(context: ModelContext) {
        let descriptor = FetchDescriptor<ModeWordProgress>()
        guard let all = try? context.fetch(descriptor) else { return }
        for row in all {
            context.delete(row)
        }
        try? context.save()
    }
}
