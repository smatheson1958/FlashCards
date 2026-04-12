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
        filter: #Predicate<CardProgress> {
            $0.deckStateRaw == "currentDeck" || $0.deckStateRaw == "successful"
        },
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
                case .words:
                    CurrentDeckWordsTabContent(cards: cards)
                case .segmentation:
                    CurrentDeckSegmentationTabContent(cards: cards)
                case .construction:
                    CurrentDeckConstructionTabContent(cards: cards)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Current deck")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Words (cumulative list from progression; grows with tiers later)

private struct CurrentDeckWordsTabContent: View {
    let cards: [CardProgress]

    var body: some View {
        Group {
            if cards.isEmpty {
                ContentUnavailableView(
                    "No cards in your deck",
                    systemImage: "square.stack",
                    description: Text("Introduce sounds from your library or complete a study session.")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        Text("Practice words follow the same ordered curriculum as Sound Cards. New tiers add words without removing earlier ones.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 4)

                        ForEach(cards, id: \.cardID) { card in
                            let snap = SoundCardProgressSnapshot(card: card)
                            let words = LearningProgressionEngine.wordsForMode(
                                orderIndex: card.orderIndex,
                                mode: .soundCards,
                                snapshot: snap
                            )
                            VStack(alignment: .leading, spacing: 4) {
                                Text(card.sound)
                                    .font(.headline)
                                Text(words.map(\.capitalized).joined(separator: ", "))
                                    .font(.body)
                                    .foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Segmentation & Construction (gated by `LearningProgressionEngine`)

private struct CurrentDeckSegmentationTabContent: View {
    let cards: [CardProgress]

    var body: some View {
        Group {
            if let card = cards.first(where: { LearningProgressionEngine.isSegmentationUnlocked(SoundCardProgressSnapshot(card: $0)) }) {
                let snap = SoundCardProgressSnapshot(card: card)
                if let word = LearningProgressionEngine.wordsForMode(
                    orderIndex: card.orderIndex,
                    mode: .segmentation,
                    snapshot: snap
                ).first {
                    let segments = ConstructionDataSource.segments(forWord: word)
                    SegmentationModeView(word: word, segments: segments)
                } else {
                    ContentUnavailableView(
                        "No word available",
                        systemImage: "waveform",
                        description: Text("Curriculum data may be missing for this sound.")
                    )
                }
            } else {
                ContentUnavailableView(
                    "Segmentation locked",
                    systemImage: "lock.fill",
                    description: Text(
                        "Get at least \(FlashCardsConstants.earlyProgressionCorrectCount) correct swipes on Sound Cards for a sound in this deck, then return here."
                    )
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CurrentDeckConstructionTabContent: View {
    let cards: [CardProgress]

    var body: some View {
        Group {
            if let card = cards.first(where: { LearningProgressionEngine.isConstructionUnlocked(SoundCardProgressSnapshot(card: $0)) }) {
                let snap = SoundCardProgressSnapshot(card: card)
                if let word = LearningProgressionEngine.wordsForMode(
                    orderIndex: card.orderIndex,
                    mode: .construction,
                    snapshot: snap
                ).first {
                    let segments = ConstructionDataSource.segments(forWord: word)
                    if segments.count >= FlashCardsConstants.constructionMinimumSegmentCount {
                        SimpleConstructionModeView(word: word, segments: segments)
                    } else {
                        ContentUnavailableView(
                            "Word too short",
                            systemImage: "character.cursor.ibeam",
                            description: Text("Construction needs at least \(FlashCardsConstants.constructionMinimumSegmentCount) pieces for this word.")
                        )
                    }
                } else {
                    ContentUnavailableView(
                        "No word available",
                        systemImage: "hammer.fill",
                        description: Text("Curriculum data may be missing for this sound.")
                    )
                }
            } else {
                ContentUnavailableView(
                    "Construction locked",
                    systemImage: "lock.fill",
                    description: Text(
                        "Get at least \(FlashCardsConstants.earlyProgressionCorrectCount) correct swipes on Sound Cards for a sound in this deck, then return here."
                    )
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Sound exercise: list of teaching-deck cards with mastery boxes (same as previous full-screen Current deck content).
private struct CurrentDeckSoundListContent: View {
    let cards: [CardProgress]

    var body: some View {
        Group {
            if cards.isEmpty {
                ContentUnavailableView(
                    "No cards in your deck",
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
    @Environment(\.modelContext) private var modelContext

    @AppStorage(FlashCardsConstants.userDefaultsKeyDebugShowSuccessfulReviewPriority)
    private var showSuccessfulReviewPriority = false

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

            VStack(alignment: .trailing, spacing: 4) {
                if showSuccessfulReviewPriority, card.deckState == .successful {
                    Text(String(format: "%.1f", card.reviewPriority))
                        .font(.caption)
                        .fontWeight(.medium)
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .accessibilityLabel("Review priority \(String(format: "%.1f", card.reviewPriority))")
                }
                MasteryFiveBoxes(
                    filledCount: min(max(card.masteryCorrectCount, 0), FlashCardsConstants.masteryThreshold)
                )
            }
            .frame(minWidth: Self.boxIndicatorWidth, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .contextMenu {
            if card.deckState == .successful {
                Button("Return to deck") {
                    DeckManager.returnToTeachingDeck(card, resetMastery: true)
                    try? modelContext.save()
                }
            }
        }
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
