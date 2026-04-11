//
//  StudySessionStore.swift
//  FlashCards
//

import Foundation
import SwiftData

@Observable
final class StudySessionStore {
    struct SessionEntry: Identifiable, Equatable {
        let id: UUID
        let cardID: String
        let isReview: Bool

        init(cardID: String, isReview: Bool) {
            self.id = UUID()
            self.cardID = cardID
            self.isReview = isReview
        }
    }

    private(set) var queue: [SessionEntry] = []
    private(set) var started = false

    var currentEntry: SessionEntry? { queue.first }
    var isComplete: Bool { started && queue.isEmpty }

    func startSession(modelContext: ModelContext) {
        let teaching = DeckManager.cards(in: .currentDeck, context: modelContext)
        let reviewIDs = weightedReviewSample(from: modelContext)
        var entries: [SessionEntry] = []
        entries.reserveCapacity(teaching.count + reviewIDs.count)
        for id in teaching.map(\.cardID) {
            entries.append(SessionEntry(cardID: id, isReview: false))
        }
        for id in reviewIDs {
            entries.append(SessionEntry(cardID: id, isReview: true))
        }
        guard !entries.isEmpty else {
            queue = []
            started = false
            return
        }
        entries.shuffle()
        queue = entries
        started = true
    }

    func resetSession() {
        queue = []
        started = false
    }

    /// Correct swipe: teaching advances progress; review adjusts priority and drops from session.
    func applyCorrect(modelContext: ModelContext) {
        guard let entry = queue.first else { return }
        guard let card = DeckManager.card(cardID: entry.cardID, context: modelContext) else {
            queue.removeFirst()
            return
        }

        card.lastReviewedDate = Date()

        if entry.isReview {
            card.reviewPriority = max(
                FlashCardsConstants.reviewPriorityMin,
                card.reviewPriority - FlashCardsConstants.reviewCorrectDelta
            )
            queue.removeFirst()
        } else {
            card.lifetimeCorrectCount += 1
            card.masteryCorrectCount += 1
            DeckManager.promoteToSuccessfulIfMastered(card, context: modelContext)
            queue.removeFirst()
        }

        try? modelContext.save()
    }

    /// Wrong swipe: teaching sends card to bottom of queue; review bumps priority and requeues (5.4).
    func applyWrong(modelContext: ModelContext) {
        guard let entry = queue.first else { return }
        guard let card = DeckManager.card(cardID: entry.cardID, context: modelContext) else {
            queue.removeFirst()
            return
        }

        card.lastReviewedDate = Date()

        if entry.isReview {
            card.reviewPriority = min(
                FlashCardsConstants.reviewPriorityMax,
                card.reviewPriority + FlashCardsConstants.reviewWrongDelta
            )
        } else {
            card.lifetimeWrongCount += 1
            card.masteryCorrectCount = 0
        }

        let moved = queue.removeFirst()
        queue.append(moved)

        try? modelContext.save()
    }

    // MARK: - Private

    private func weightedReviewSample(from context: ModelContext) -> [String] {
        var pool = DeckManager.cards(in: .successful, context: context)
        guard !pool.isEmpty else { return [] }

        let teachingIDs = Set(DeckManager.cards(in: .currentDeck, context: context).map(\.cardID))
        pool.removeAll { teachingIDs.contains($0.cardID) }

        let maxPick = FlashCardsConstants.maxReviewCardsPerSession
        var picked: [String] = []
        picked.reserveCapacity(maxPick)

        for _ in 0 ..< maxPick where !pool.isEmpty {
            let weights = pool.map { max(FlashCardsConstants.reviewPriorityMin, $0.reviewPriority) }
            let total = weights.reduce(0, +)
            guard total > 0 else { break }

            var roll = Double.random(in: 0 ..< total)
            var chosenIndex = pool.indices.lowerBound
            for i in pool.indices {
                roll -= weights[i]
                if roll < 0 {
                    chosenIndex = i
                    break
                }
                chosenIndex = i
            }
            let card = pool.remove(at: chosenIndex)
            picked.append(card.cardID)
        }

        return picked
    }
}
