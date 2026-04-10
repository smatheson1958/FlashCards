//
//  CurrentDeckListView.swift
//  FlashCards
//

import SwiftData
import SwiftUI

private enum CurrentDeckExerciseTab: String, CaseIterable, Identifiable {
    case sound
    case words
    case segmentation
    case construction

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sound: "Sound"
        case .words: "Words"
        case .segmentation: "Segmentation"
        case .construction: "Construction"
        }
    }
}

struct CurrentDeckListView: View {
    @State private var selectedExerciseTab: CurrentDeckExerciseTab = .sound

    @Query(
        filter: #Predicate<CardProgress> { $0.deckStateRaw == "currentDeck" },
        sort: \CardProgress.orderIndex
    )
    private var cards: [CardProgress]

    var body: some View {
        VStack(spacing: 0) {
            Picker("Exercise", selection: $selectedExerciseTab) {
                ForEach(CurrentDeckExerciseTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Group {
                switch selectedExerciseTab {
                case .sound:
                    CurrentDeckSoundListContent(cards: cards)
                case .words, .segmentation, .construction:
                    ContentUnavailableView(
                        "Coming soon",
                        systemImage: "square.dashed",
                        description: Text("This exercise will be shown here.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Current deck")
        .navigationBarTitleDisplayMode(.large)
    }
}

/// Sound exercise: list of teaching-deck cards with mastery boxes (same as previous full-screen Current deck content).
private struct CurrentDeckSoundListContent: View {
    let cards: [CardProgress]

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
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(cards.enumerated()), id: \.element.cardID) { index, card in
                            CurrentDeckRow(card: card)
                                .padding(.horizontal, 16)
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
    }
}

private struct CurrentDeckRow: View {
    let card: CardProgress

    /// Fixed width so every row’s sound and word columns line up.
    private static let soundColumnWidth: CGFloat = 44
    private static let boxIndicatorWidth: CGFloat = MasteryFiveBoxes.totalWidth

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

            MasteryFiveBoxes(
                filledCount: min(max(card.masteryCorrectCount, 0), FlashCardsConstants.masteryThreshold)
            )
            .frame(width: Self.boxIndicatorWidth, alignment: .trailing)
        }
        .padding(.vertical, 10)
    }
}

/// Five small squares: first `filledCount` are filled green; the rest are outlined only.
private struct MasteryFiveBoxes: View {
    let filledCount: Int

    private static let boxSize: CGFloat = 12
    private static let boxSpacing: CGFloat = 4

    static var totalWidth: CGFloat {
        CGFloat(FlashCardsConstants.masteryThreshold) * boxSize
            + CGFloat(FlashCardsConstants.masteryThreshold - 1) * boxSpacing
    }

    var body: some View {
        HStack(spacing: Self.boxSpacing) {
            ForEach(0..<FlashCardsConstants.masteryThreshold, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(index < filledCount ? Color.green : Color.clear)
                    .frame(width: Self.boxSize, height: Self.boxSize)
                    .overlay {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .stroke(Color.secondary.opacity(0.55), lineWidth: 1)
                    }
            }
        }
        .accessibilityLabel("\(filledCount) of \(FlashCardsConstants.masteryThreshold) correct toward mastery")
    }
}

#Preview {
    NavigationStack {
        CurrentDeckListView()
    }
    .modelContainer(for: CardProgress.self, inMemory: true)
}
