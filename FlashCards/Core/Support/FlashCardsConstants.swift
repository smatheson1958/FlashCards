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

    /// Teaching-deck size and phonics “working sounds” cap. Must match `totalSounds` in bundled `Seed/sound_units_primary_index_146.json` (see `SoundUnitsPrimaryIndexLoader`).
    static let currentDeckTargetCount = 146

    /// On first seed only: how many sounds start in the teaching deck (`currentDeck`), in `orderIndex` order. Additional sounds enter via `DeckManager.introduceNextCardsToReachTarget` as the learner progresses.
    static let initialSoundDeckIntroLimit = 30
    static let maxReviewCardsPerSession = 5
    static let reviewPriorityMin = 0.25
    static let reviewPriorityMax = 50.0
    static let reviewCorrectDelta = 0.5
    static let reviewWrongDelta = 1.0

    // MARK: Debug (UserDefaults; toggles only in Debug tab)

    /// When true, the deck list shows each mastered card’s review-priority weight (Sounds review sampling).
    static let userDefaultsKeyDebugShowSuccessfulReviewPriority = "debugShowSuccessfulReviewPriority"

    // MARK: Construction activity (POC from bundled JSON)

    /// Activities need at least this many ordered pieces to be worth showing.
    static let constructionMinimumSegmentCount = 2

    /// Extra tile labels mixed with the target segments (see `ConstructionTilePoolBuilder`).
    static let constructionDistractorCountShortWord = 1
    static let constructionDistractorCountLongWord = 2
}
