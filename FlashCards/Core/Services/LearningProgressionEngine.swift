//
//  LearningProgressionEngine.swift
//  FlashCards
//
//  Single decision layer for Construction, Segmentation, Memory, and practice word sets.
//  Sound Cards remain the source of truth: callers pass snapshots derived from `CardProgress`.
//

import Foundation

/// Modes that consult the master curriculum (`supportsModes`) plus Sound Card progress.
enum LearningPracticeMode: String, Sendable {
    case soundCards
    case construction
    case segmentation
    case memory
}

/// Read-only view of Sound Card state for progression (no SwiftData).
struct SoundCardProgressSnapshot: Equatable, Sendable {
    /// Matches `CardProgress.orderIndex` and `SoundUnitEntryDTO.orderIndex` in the master list (1…N).
    let orderIndex: Int
    let masteryCorrectCount: Int
    let deckState: DeckState

    init(orderIndex: Int, masteryCorrectCount: Int, deckState: DeckState) {
        self.orderIndex = orderIndex
        self.masteryCorrectCount = masteryCorrectCount
        self.deckState = deckState
    }

    init(card: CardProgress) {
        self.orderIndex = card.orderIndex
        self.masteryCorrectCount = card.masteryCorrectCount
        self.deckState = card.deckState
    }
}

enum LearningProgressionEngine {
    private static var cachedRoot: SoundUnitsPrimaryIndexRoot?
    private static let cacheLock = NSLock()

    /// Clears cached curriculum (e.g. after tests replace bundle resources).
    static func clearCurriculumCacheForTesting() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cachedRoot = nil
    }

    static func curriculumRoot() throws -> SoundUnitsPrimaryIndexRoot {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cachedRoot {
            return cachedRoot
        }
        let root = try SoundUnitsPrimaryIndexLoader.load()
        cachedRoot = root
        return root
    }

    /// Curriculum row for this card’s position in the master order (preferred over matching `sound` string — duplicates exist).
    static func curriculumEntry(forOrderIndex orderIndex: Int) -> SoundUnitEntryDTO? {
        guard let root = try? curriculumRoot() else { return nil }
        return root.sounds.first { $0.orderIndex == orderIndex }
    }

    /// Example / anchor word when sound-units JSON is missing or has no row (fallback to G1 construction index).
    private static func fallbackExampleWord(forOrderIndex orderIndex: Int) -> String? {
        guard let item = ConstructionIndexG1Loader.item(forSoundOrderIndex: orderIndex) else { return nil }
        let anchor = item.anchorWord?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !anchor.isEmpty { return anchor }
        let first = item.constructionSets.first?.word.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return first.isEmpty ? nil : first
    }

    /// Whether construction exercises are defined for this sound (master `supportsModes`, else G1 construction index row).
    private static func curriculumAllowsConstruction(at orderIndex: Int) -> Bool {
        if let modes = curriculumEntry(forOrderIndex: orderIndex)?.supportsModes {
            return modes.construction
        }
        return ConstructionIndexG1Loader.item(forSoundOrderIndex: orderIndex) != nil
    }

    /// Whether segmentation exercises are defined for this sound (master `supportsModes`, else G1 index — same `graphemeUnits`).
    private static func curriculumAllowsSegmentation(at orderIndex: Int) -> Bool {
        if let modes = curriculumEntry(forOrderIndex: orderIndex)?.supportsModes {
            return modes.segmentation
        }
        return ConstructionIndexG1Loader.item(forSoundOrderIndex: orderIndex) != nil
    }

    /// Sound Cards have enough correct swipes (or are mastered) to unlock Construction / Segmentation for that sound.
    static func hasUnlockedConstructionOrSegmentationSoundWork(_ snapshot: SoundCardProgressSnapshot) -> Bool {
        switch snapshot.deckState {
        case .successful:
            return true
        case .currentDeck:
            return snapshot.masteryCorrectCount >= FlashCardsConstants.constructionSegmentationMinSoundCardCorrect
        case .notIntroduced:
            return false
        }
    }

    /// Whether the sound has reached the successful pool (mastered at threshold). Enables Memory when curriculum allows.
    static func isInSuccessfulPool(_ snapshot: SoundCardProgressSnapshot) -> Bool {
        snapshot.deckState == .successful
    }

    static func isConstructionUnlocked(_ snapshot: SoundCardProgressSnapshot) -> Bool {
        curriculumAllowsConstruction(at: snapshot.orderIndex) && hasUnlockedConstructionOrSegmentationSoundWork(snapshot)
    }

    static func isSegmentationUnlocked(_ snapshot: SoundCardProgressSnapshot) -> Bool {
        curriculumAllowsSegmentation(at: snapshot.orderIndex) && hasUnlockedConstructionOrSegmentationSoundWork(snapshot)
    }

    static func isMemoryUnlocked(_ snapshot: SoundCardProgressSnapshot) -> Bool {
        guard let modes = curriculumEntry(forOrderIndex: snapshot.orderIndex)?.supportsModes else { return false }
        return modes.memory && isInSuccessfulPool(snapshot)
    }

    /// Cumulative word set for this sound at the current progress stage. Uses sound-units master when present; otherwise G1 construction index.
    static func wordsForMode(orderIndex: Int, mode: LearningPracticeMode, snapshot: SoundCardProgressSnapshot) -> [String] {
        let curriculumWord: String? = {
            guard let entry = curriculumEntry(forOrderIndex: orderIndex) else { return nil }
            let w = entry.exampleWord.trimmingCharacters(in: .whitespacesAndNewlines)
            return w.isEmpty ? nil : w
        }()
        let fallbackWord = fallbackExampleWord(forOrderIndex: orderIndex)
        let exampleWord = curriculumWord ?? fallbackWord
        guard let word = exampleWord else {
            if mode == .construction && isConstructionUnlocked(snapshot) {
                return ConstructionIndexG1Loader.stage4FirstFiveWords(forSoundOrderIndex: orderIndex)
            }
            if mode == .segmentation && isSegmentationUnlocked(snapshot) {
                return ConstructionIndexG1Loader.stage4FirstFiveWords(forSoundOrderIndex: orderIndex)
            }
            return []
        }

        switch mode {
        case .soundCards:
            return [word]
        case .construction:
            guard isConstructionUnlocked(snapshot) else { return [] }
            let fromIndex = ConstructionIndexG1Loader.stage4FirstFiveWords(forSoundOrderIndex: orderIndex)
            return fromIndex.isEmpty ? [word] : fromIndex
        case .segmentation:
            guard isSegmentationUnlocked(snapshot) else { return [] }
            let fromIndex = ConstructionIndexG1Loader.stage4FirstFiveWords(forSoundOrderIndex: orderIndex)
            return fromIndex.isEmpty ? [word] : fromIndex
        case .memory:
            return isMemoryUnlocked(snapshot) ? [word] : []
        }
    }
}
