//
//  DeckManager.swift
//  FlashCards
//

import Foundation
import SwiftData

/// Central place for deck lifecycle: move to successful, return to teaching deck, introduce next cards.
enum DeckManager {
    // MARK: - Queries

    static func cards(in deckState: DeckState, context: ModelContext) -> [CardProgress] {
        let raw = deckState.rawValue
        let descriptor = FetchDescriptor<CardProgress>(
            predicate: #Predicate { $0.deckStateRaw == raw },
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func card(cardID: String, context: ModelContext) -> CardProgress? {
        let id = cardID
        let descriptor = FetchDescriptor<CardProgress>(
            predicate: #Predicate { $0.cardID == id }
        )
        return try? context.fetch(descriptor).first
    }

    // MARK: - Bootstrap (seed placement)

    static func bootstrapDeckState(zeroBasedIndex: Int, introLimit: Int) -> DeckState {
        zeroBasedIndex < introLimit ? .currentDeck : .notIntroduced
    }

    // MARK: - Move to successful

    /// Sets mastered state and moves the card to the successful pool (no introduce).
    static func moveToSuccessful(_ card: CardProgress) {
        card.deckState = .successful
        card.masteryCorrectCount = FlashCardsConstants.masteryThreshold
    }

    /// After `masteryCorrectCount` has been updated: graduate if threshold met and backfill teaching deck.
    /// - Returns: `true` if the card was graduated this call.
    @discardableResult
    static func promoteToSuccessfulIfMastered(_ card: CardProgress, context: ModelContext) -> Bool {
        guard card.deckState == .currentDeck else { return false }
        guard card.masteryCorrectCount >= FlashCardsConstants.masteryThreshold else { return false }
        moveToSuccessful(card)
        introduceNextCardsToReachTarget(context: context)
        return true
    }

    // MARK: - Introduce next cards

    /// Pulls cards from `notIntroduced` into `currentDeck` until teaching count reaches `targetCount`.
    static func introduceNextCardsToReachTarget(
        context: ModelContext,
        targetCount: Int = FlashCardsConstants.currentDeckTargetCount
    ) {
        let current = cards(in: .currentDeck, context: context).count
        let deficit = targetCount - current
        guard deficit > 0 else { return }

        let notIntro = DeckState.notIntroduced.rawValue
        let descriptor = FetchDescriptor<CardProgress>(
            predicate: #Predicate { $0.deckStateRaw == notIntro },
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        guard var waiting = try? context.fetch(descriptor) else { return }

        waiting.sort { $0.orderIndex < $1.orderIndex }
        for card in waiting.prefix(deficit) {
            card.deckState = .currentDeck
            if card.introducedDate == nil {
                card.introducedDate = Date()
            }
        }
    }

    // MARK: - Return to deck

    /// Moves a card from **successful** back into the **current teaching deck** for more practice.
    /// - Parameters:
    ///   - resetMastery: When `true`, clears progress toward the mastery threshold (default).
    static func returnToTeachingDeck(
        _ card: CardProgress,
        resetMastery: Bool = true
    ) {
        guard card.deckState == .successful else { return }
        card.deckState = .currentDeck
        if resetMastery {
            card.masteryCorrectCount = 0
        }
        if card.introducedDate == nil {
            card.introducedDate = Date()
        }
    }
}
