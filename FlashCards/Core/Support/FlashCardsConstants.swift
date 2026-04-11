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

    /// Correct swipes on Sound Cards toward mastery required before Construction / Segmentation unlock (while still in the teaching deck).
    static let earlyProgressionCorrectCount = 2

    static let currentDeckTargetCount = 30
    static let maxReviewCardsPerSession = 5
    static let reviewPriorityMin = 0.25
    static let reviewPriorityMax = 50.0
    static let reviewCorrectDelta = 0.5
    static let reviewWrongDelta = 1.0

    // MARK: Construction activity (POC from bundled JSON)

    /// Activities need at least this many ordered pieces to be worth showing.
    static let constructionMinimumSegmentCount = 2

    /// Extra tile labels mixed with the target segments (see `ConstructionTilePoolBuilder`).
    static let constructionDistractorCountShortWord = 1
    static let constructionDistractorCountLongWord = 2
}
