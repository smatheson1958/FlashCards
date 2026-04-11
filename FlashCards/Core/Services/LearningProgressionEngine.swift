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

    /// Whether the learner has reached “early success” on Sound Cards (unlocks Construction + Segmentation when curriculum allows).
    static func hasEarlySoundCardSuccess(_ snapshot: SoundCardProgressSnapshot) -> Bool {
        switch snapshot.deckState {
        case .successful:
            return true
        case .currentDeck:
            return snapshot.masteryCorrectCount >= FlashCardsConstants.earlyProgressionCorrectCount
        case .notIntroduced:
            return false
        }
    }

    /// Whether the sound has reached the successful pool (mastered at threshold). Enables Memory when curriculum allows.
    static func isInSuccessfulPool(_ snapshot: SoundCardProgressSnapshot) -> Bool {
        snapshot.deckState == .successful
    }

    static func isConstructionUnlocked(_ snapshot: SoundCardProgressSnapshot) -> Bool {
        guard let modes = curriculumEntry(forOrderIndex: snapshot.orderIndex)?.supportsModes else { return false }
        return modes.construction && hasEarlySoundCardSuccess(snapshot)
    }

    static func isSegmentationUnlocked(_ snapshot: SoundCardProgressSnapshot) -> Bool {
        guard let modes = curriculumEntry(forOrderIndex: snapshot.orderIndex)?.supportsModes else { return false }
        return modes.segmentation && hasEarlySoundCardSuccess(snapshot)
    }

    static func isMemoryUnlocked(_ snapshot: SoundCardProgressSnapshot) -> Bool {
        guard let modes = curriculumEntry(forOrderIndex: snapshot.orderIndex)?.supportsModes else { return false }
        return modes.memory && isInSuccessfulPool(snapshot)
    }

    /// Cumulative word set for this sound at the current progress stage. MVP: example word from master JSON; later tiers append without replacing earlier words.
    static func wordsForMode(orderIndex: Int, mode: LearningPracticeMode, snapshot: SoundCardProgressSnapshot) -> [String] {
        guard let entry = curriculumEntry(forOrderIndex: orderIndex) else { return [] }
        let word = entry.exampleWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return [] }

        switch mode {
        case .soundCards:
            return [word]
        case .construction:
            return isConstructionUnlocked(snapshot) ? [word] : []
        case .segmentation:
            return isSegmentationUnlocked(snapshot) ? [word] : []
        case .memory:
            return isMemoryUnlocked(snapshot) ? [word] : []
        }
    }
}
