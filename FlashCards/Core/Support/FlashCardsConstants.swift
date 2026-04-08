//
//  FlashCardsConstants.swift
//  FlashCards
//

import Foundation

enum FlashCardsConstants {
    static let masteryThreshold = 5
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
