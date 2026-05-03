//
//  FlashCardsConstants.swift
//  FlashCards
//

import Foundation

enum FlashCardsConstants {
    // MARK: Standard delay (shared across exercises)

    /// Default duration for the three-dot “time until next action” indicator (`StandardDelayCountdownIndicator`).
    enum StandardDelay {
        static let seconds: TimeInterval = 3
        static let tickCount: Int = 3

        /// One sleep per tick; `seconds` split evenly across `tickCount` (e.g. 1s × 3 when `seconds` is 3).
        static var nanosecondsPerTick: UInt64 {
            UInt64((seconds / Double(tickCount) * 1_000_000_000.0).rounded())
        }
    }

    static let masteryThreshold = 5

    /// Sound Card correct count required before Construction / Segmentation exercises unlock for that sound (teaching or successful pool).
    static let constructionSegmentationMinSoundCardCorrect = 3

    /// Successful Construction or Segmentation completions required per word (same count as Sound Card mastery boxes).
    static let modeExerciseWordMasteryCount = 5

    /// When opening construction or segmentation from the working-sounds list, at most this many words are practised in one visit before returning to the list.
    static let phonicsWordsPerSoundDrillSession = 2

    /// Total sounds in the primary curriculum and cap for phonics “working sounds” lists (Construction / Segmentation). Must match `totalSounds` in bundled `Seed/sound_units_primary_index_146.json` (see `SoundUnitsPrimaryIndexLoader`). Not the count of `currentDeck` rows to maintain after each mastery.
    static let currentDeckTargetCount = 146

    /// How many sounds sit in the teaching deck (`currentDeck`) at once: this many are seeded on first import and `DeckManager.introduceNextCardsToReachTarget` refills toward this count when a card graduates (typically one new sound per completion).
    static let initialSoundDeckIntroLimit = 30
    static let maxReviewCardsPerSession = 5
    static let reviewPriorityMin = 0.25
    static let reviewPriorityMax = 50.0
    static let reviewCorrectDelta = 0.5
    static let reviewWrongDelta = 1.0

    // MARK: Debug (UserDefaults; toggles only in Debug tab)

    /// When true, the deck list shows each mastered card’s review-priority weight (Sounds review sampling).
    static let userDefaultsKeyDebugShowSuccessfulReviewPriority = "debugShowSuccessfulReviewPriority"

    /// When true, tapping a mastery square on the Current deck or Construction/Segmentation lists sets progress to that position (e.g. 4th square → worked 4 times).
    static let userDefaultsKeyDebugAdjustProgressSquares = "debugAdjustProgressSquares"

    // MARK: Construction activity (POC from bundled JSON)

    // MARK: Phonics structure bundle (`phonics_structure.json`; visit pairs per sound)

    /// Minimum successes and distinct words before checking recency for “segmentation secure” (module-only).
    enum SegmentationJourneySecure {
        static let minSuccessCount = 5
        static let minDistinctWords = 4
        static let recentWindowSize = 8
        static let minRecentAccuracy = 0.75
        static let maxRecentOutcomeChars = 32
    }

    /// Activities need at least this many ordered pieces to be worth showing.
    static let constructionMinimumSegmentCount = 2

    /// Extra tile labels mixed with the target segments (see `ConstructionTilePoolBuilder`).
    static let constructionDistractorCountShortWord = 1
    static let constructionDistractorCountLongWord = 2
}
