//
//  SuccessfulListView.swift
//  FlashCards
//

import SwiftData
import SwiftUI

struct SuccessfulListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<CardProgress> { $0.deckStateRaw == "successful" },
        sort: \CardProgress.orderIndex
    )
    private var cards: [CardProgress]

    var body: some View {
        Group {
            if cards.isEmpty {
                ContentUnavailableView(
                    "No mastered sounds yet",
                    systemImage: "checkmark.circle",
                    description: Text("Sounds move here after five correct answers in a row while in the current deck.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(cards, id: \.cardID) { card in
                        SuccessfulDeckRow(card: card)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Return to deck") {
                                    DeckManager.returnToTeachingDeck(card, resetMastery: true)
                                    try? modelContext.save()
                                }
                                .tint(.orange)
                            }
                    }
                }
            }
        }
        .navigationTitle("Successful")
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct SuccessfulDeckRow: View {
    let card: CardProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(card.sound)
                    .font(.title2.weight(.semibold))
                Spacer()
                Text(String(format: "priority %.1f", card.reviewPriority))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            Text(card.word.capitalized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        SuccessfulListView()
    }
    .modelContainer(for: CardProgress.self, inMemory: true)
}
