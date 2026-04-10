//
//  WordStudyView.swift
//  FlashCards
//

import Observation
import SwiftData
import SwiftUI
import UIKit

struct WordStudyView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WordCard.orderIndex) private var wordCards: [WordCard]
    @Bindable private var appearance = StudyAppearanceSettings.shared

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
        .background(appearance.backgroundColor)
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
                .tint(appearance.surroundColor)
            Text("Building word list…")
                .font(appearance.bodyFont(size: 17, weight: .semibold))
            Text("Loading entries from words.json. This only runs once.")
                .font(appearance.bodyFont(size: 15))
                .foregroundStyle(appearance.surroundColor.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(appearance.backgroundColor)
    }

    private var wordStudyContent: some View {
        let card = wordCards[index]

        return VStack(spacing: 24) {
            Text("Word \(index + 1) of \(wordCards.count)")
                .font(appearance.bodyFont(size: 15))
                .foregroundStyle(appearance.surroundColor.opacity(0.9))

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
                .fill(appearance.cardFillColor)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(appearance.surroundColor.opacity(0.45), lineWidth: 1.5)
                }
                .shadow(color: appearance.surroundColor.opacity(0.25), radius: 12, y: 6)

            VStack(spacing: 16) {
                Text(card.word.capitalized)
                    .font(appearance.titleFont(size: 48, weight: .semibold))
                    .foregroundStyle(appearance.primaryTextColor)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        audio.play(stem: card.playbackStem)
                    }

                Label("Tap word to hear", systemImage: "speaker.wave.2.fill")
                    .font(appearance.bodyFont(size: 13))
                    .foregroundStyle(appearance.surroundColor.opacity(0.7))
            }
            .padding(36)
        }
        .frame(maxWidth: 520)
        .frame(minHeight: 260)
    }

    private var controls: some View {
        HStack(spacing: 40) {
            Button {
                step(-1)
            } label: {
                wordStudyNavCircleSymbol("chevron.left.circle.fill")
            }
            .disabled(index <= 0)

            Button {
                audio.stop()
            } label: {
                wordStudyNavCircleSymbol("stop.circle")
            }
            .accessibilityLabel("Stop")

            Button {
                step(1)
            } label: {
                wordStudyNavCircleSymbol("chevron.right.circle.fill")
            }
            .disabled(index >= wordCards.count - 1)
        }
        .padding(.bottom, 8)
    }

    /// Prev/next/stop circle symbols use system dark gray so they stay readable on any study theme.
    private func wordStudyNavCircleSymbol(_ systemName: String) -> some View {
        let gray = Color(uiColor: .darkGray)
        return Image(systemName: systemName)
            .font(.system(size: 44))
            .symbolRenderingMode(.palette)
            .foregroundStyle(gray, gray.opacity(0.22))
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
