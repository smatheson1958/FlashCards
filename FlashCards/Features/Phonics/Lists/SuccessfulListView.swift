//
//  SuccessfulListView.swift
//  FlashCards
//

import SwiftData
import SwiftUI

struct SuccessfulListView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage(FlashCardsConstants.userDefaultsKeyDebugShowSuccessfulReviewPriority)
    private var showSuccessfulReviewPriority = false

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
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(cards.enumerated()), id: \.element.cardID) { index, card in
                            SuccessfulDeckRow(card: card, showPriority: showSuccessfulReviewPriority)
                                .padding(.horizontal, 16)
                                .contextMenu {
                                    Button("Return to deck") {
                                        DeckManager.returnToTeachingDeck(card, resetMastery: true)
                                        try? modelContext.save()
                                    }
                                }
                            if index < cards.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .navigationTitle("Successful")
        .navigationBarTitleDisplayMode(.large)
    }
}

/// Matches `CurrentDeckRow` layout: sound column, word, optional trailing review priority (same width as mastery boxes when shown).
private struct SuccessfulDeckRow: View {
    let card: CardProgress
    var showPriority: Bool

    private static let soundColumnWidth: CGFloat = 44
    /// Same width as `MasteryFiveBoxes` in `CurrentDeckListView` so columns line up across tabs.
    private static let trailingColumnWidth: CGFloat = {
        let boxSize: CGFloat = 12
        let boxSpacing: CGFloat = 4
        let n = FlashCardsConstants.masteryThreshold
        return CGFloat(n) * boxSize + CGFloat(n - 1) * boxSpacing
    }()

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(card.sound)
                .font(.title3.weight(.semibold))
                .frame(width: Self.soundColumnWidth, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(card.word.capitalized)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)

            if showPriority {
                Text(String(format: "%.1f", card.reviewPriority))
                    .font(.caption)
                    .fontWeight(.medium)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .frame(width: Self.trailingColumnWidth, alignment: .trailing)
                    .accessibilityLabel("Review priority \(String(format: "%.1f", card.reviewPriority))")
            }
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        SuccessfulListView()
    }
    .modelContainer(for: CardProgress.self, inMemory: true)
}
