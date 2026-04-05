//
//  CurrentDeckListView.swift
//  FlashCards
//

import SwiftData
import SwiftUI

struct CurrentDeckListView: View {
    @Query(
        filter: #Predicate<CardProgress> { $0.deckStateRaw == "currentDeck" },
        sort: \CardProgress.orderIndex
    )
    private var cards: [CardProgress]

    var body: some View {
        Group {
            if cards.isEmpty {
                ContentUnavailableView(
                    "No active cards",
                    systemImage: "square.stack",
                    description: Text("Introduce more from your library or complete a study session.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(cards, id: \.cardID) { card in
                        CurrentDeckRow(card: card)
                    }
                }
            }
        }
        .navigationTitle("Current deck")
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct CurrentDeckRow: View {
    let card: CardProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(card.sound)
                    .font(.title2.weight(.semibold))
                Spacer()
                Text("\(card.masteryCorrectCount)/\(FlashCardsConstants.masteryThreshold)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary.opacity(0.35), in: Capsule())
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
        CurrentDeckListView()
    }
    .modelContainer(for: CardProgress.self, inMemory: true)
}
