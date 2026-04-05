//
//  WordStudyView.swift
//  FlashCards
//

import SwiftData
import SwiftUI

struct WordStudyView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WordCard.orderIndex) private var wordCards: [WordCard]

    var isLibraryPreparing: Bool = false

    @State private var index = 0
    @State private var audio = WordAudioPlayer()

    var body: some View {
        Group {
            if isLibraryPreparing {
                wordLibraryPreparingView
            } else if wordCards.isEmpty {
                ContentUnavailableView(
                    "No words yet",
                    systemImage: "text.bubble",
                    description: Text("Word cards load from words.json after first launch.")
                )
            } else {
                wordStudyContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .onChange(of: wordCards.count) { _, newCount in
            if index >= newCount { index = max(0, newCount - 1) }
        }
        .onChange(of: index) { _, _ in
            audio.clearPlaybackWarning()
        }
    }

    private var wordLibraryPreparingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.25)
            Text("Building word list…")
                .font(.headline)
            Text("Loading entries from words.json. This only runs once.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var wordStudyContent: some View {
        let card = wordCards[index]

        return VStack(spacing: 24) {
            Text("Word \(index + 1) of \(wordCards.count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            wordFace(card: card)
                .padding(.horizontal, 20)

            if audio.lastPlaybackFailed {
                Text("Audio file missing — add \(card.playbackStem).wav to the bundle (WordsAudio).")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            controls
        }
    }

    private func wordFace(card: WordCard) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 6)

            VStack(spacing: 16) {
                Text(card.word.capitalized)
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)

                Label("Tap to hear", systemImage: "speaker.wave.2.fill")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding(36)
        }
        .frame(maxWidth: 520)
        .frame(minHeight: 260)
        .contentShape(Rectangle())
        .onTapGesture {
            audio.play(stem: card.playbackStem)
        }
    }

    private var controls: some View {
        HStack(spacing: 40) {
            Button {
                step(-1)
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 44))
            }
            .disabled(index <= 0)

            Button {
                audio.stop()
            } label: {
                Label("Stop", systemImage: "stop.circle")
            }

            Button {
                step(1)
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 44))
            }
            .disabled(index >= wordCards.count - 1)
        }
        .labelStyle(.iconOnly)
        .padding(.bottom, 8)
    }

    private func step(_ delta: Int) {
        let next = index + delta
        guard wordCards.indices.contains(next) else { return }
        audio.stop()
        audio.clearPlaybackWarning()
        index = next
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: WordCard.self, configurations: config)
    let ctx = ModelContext(container)
    ctx.insert(WordCard(wordID: "word_001", orderIndex: 1, word: "cat", audioStem: "cat"))
    return NavigationStack {
        WordStudyView()
    }
    .modelContainer(container)
}
