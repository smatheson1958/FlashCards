//
//  FlashCardStudyView.swift
//  FlashCards
//

import Observation
import SwiftData
import SwiftUI
import UIKit

struct FlashCardStudyView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: StudySessionStore
    /// True while bundled JSON is imported into SwiftData on first launch.
    var isLibraryPreparing: Bool = false

    @State private var showingBack = false
    @State private var dragOffset: CGSize = .zero
    @State private var flipDegrees: Double = 0
    @State private var isBuildingSession = false
    @State private var showEmptyDeckAlert = false

    private let swipeThreshold: CGFloat = 96

    var body: some View {
        VStack(spacing: 20) {
            if isLibraryPreparing {
                libraryPreparingView
            } else if session.isComplete {
                sessionCompleteView
            } else if let entry = session.currentEntry,
                      let card = resolveCard(cardID: entry.cardID) {
                progressHint(card: card, isReview: entry.isReview)
                cardFace(card: card, isReview: entry.isReview)
                    .padding(.horizontal, 20)
                hintRow
            } else if isBuildingSession {
                buildingSessionView
            } else if session.started {
                ContentUnavailableView("No cards", systemImage: "rectangle.stack")
            } else {
                startPrompt
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .animation(.spring(duration: 0.45, bounce: 0.22), value: showingBack)
        .animation(.spring(duration: 0.45, bounce: 0.22), value: flipDegrees)
        .onChange(of: session.currentEntry?.id) { _, _ in
            isBuildingSession = false
            showingBack = false
            flipDegrees = 0
            dragOffset = .zero
        }
        .onChange(of: session.started) { _, started in
            if !started { isBuildingSession = false }
        }
        .alert("Nothing to study", isPresented: $showEmptyDeckAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("There are no cards in your current deck yet. Open the Current deck tab after the library finishes loading, or delete and reinstall if setup didn’t complete.")
        }
    }

    private var libraryPreparingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.25)
                .tint(.accentColor)
            Text("Building your library…")
                .font(.headline)
            Text("Loading sounds and cards from the bundled reference files. This only runs once.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding()
    }

    private var buildingSessionView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Preparing your session…")
                .font(.headline)
            Text("Shuffling the current deck and review cards.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
        .padding()
    }

    private func beginSession(resetFirst: Bool = false) {
        if resetFirst {
            session.resetSession()
        }
        isBuildingSession = true
        SeedImporter.repairSeededFlagIfPhonicsStoreEmpty(context: modelContext)
        try? SeedImporter.importIfNeeded(context: modelContext)
        session.startSession(modelContext: modelContext)
        if !session.started {
            showEmptyDeckAlert = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120_000_000)
            isBuildingSession = false
        }
    }

    private var startPrompt: some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "Study",
                systemImage: "rectangle.on.rectangle.angled",
                description: Text("Start a session to practise sounds. Tap to flip, then swipe right for correct or left for wrong.")
            )
            Button("Start session") {
                beginSession()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isLibraryPreparing)
        }
        .padding()
    }

    private var sessionCompleteView: some View {
        VStack(spacing: 20) {
            ContentUnavailableView(
                "Session complete",
                systemImage: "checkmark.circle",
                description: Text("Nice work. Start again when you're ready.")
            )
            Button("New session") {
                beginSession(resetFirst: true)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }

    private var hintRow: some View {
        HStack {
            Label("Wrong", systemImage: "arrow.left")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Label("Correct", systemImage: "arrow.right")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 32)
    }

    @ViewBuilder
    private func progressHint(card: CardProgress, isReview: Bool) -> some View {
        HStack {
            if isReview {
                Text("Review")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.2), in: Capsule())
            }
            Spacer()
            if !isReview {
                Text("\(card.masteryCorrectCount)/\(FlashCardsConstants.masteryThreshold)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24)
    }

    private func cardFace(card: CardProgress, isReview: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 6)

            Group {
                if showingBack {
                    backContent(card: card)
                        .rotation3DEffect(.degrees(-flipDegrees), axis: (x: 0, y: 1, z: 0))
                } else {
                    frontContent(card: card)
                }
            }
            .padding(28)
            .rotation3DEffect(.degrees(flipDegrees), axis: (x: 0, y: 1, z: 0))
        }
        .frame(maxWidth: 520)
        .frame(minHeight: 280)
        .offset(dragOffset)
        .onTapGesture {
            withAnimation(.spring(duration: 0.5, bounce: 0.18)) {
                showingBack.toggle()
                flipDegrees = showingBack ? 180 : 0
            }
        }
        .simultaneousGesture(swipeGesture)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onChanged { value in
                guard showingBack else { return }
                dragOffset = CGSize(width: value.translation.width, height: value.translation.height * 0.15)
            }
            .onEnded { value in
                guard showingBack else {
                    dragOffset = .zero
                    return
                }
                let w = value.translation.width
                if w > swipeThreshold {
                    commitSwipe(correct: true)
                } else if w < -swipeThreshold {
                    commitSwipe(correct: false)
                } else {
                    withAnimation(.spring) { dragOffset = .zero }
                }
            }
    }

    private func commitSwipe(correct: Bool) {
        withAnimation(.easeOut(duration: 0.2)) {
            dragOffset = CGSize(width: correct ? 500 : -500, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            if correct {
                session.applyCorrect(modelContext: modelContext)
            } else {
                session.applyWrong(modelContext: modelContext)
            }
            dragOffset = .zero
        }
    }

    private func frontContent(card: CardProgress) -> some View {
        VStack(spacing: 12) {
            Text("Sound")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(card.sound)
                .font(.system(size: 72, weight: .medium, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text("Tap to flip")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
    }

    private func backContent(card: CardProgress) -> some View {
        VStack(spacing: 16) {
            Text("Word")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(card.word.capitalized)
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
            cardImage(card: card)
            Text("Swipe → correct, ← wrong")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func cardImage(card: CardProgress) -> some View {
        switch card.imageSource {
        case .none:
            EmptyView()
        case .bundled:
            if let name = card.bundledImageName,
               let ui = UIImage(named: name) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        case .sfSymbol:
            if let name = card.symbolName {
                Image(systemName: name)
                    .font(.system(size: 56))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
            }
        case .userPhoto:
            if let path = card.userImagePath,
               let ui = UIImage(contentsOfFile: path) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func resolveCard(cardID: String) -> CardProgress? {
        DeckManager.card(cardID: cardID, context: modelContext)
    }
}

#Preview {
    FlashCardStudyPreview()
}

private struct FlashCardStudyPreview: View {
    @State private var session = StudySessionStore()
    private let container: ModelContainer

    init() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let c = try! ModelContainer(for: CardProgress.self, configurations: config)
        let ctx = c.mainContext
        ctx.insert(
            CardProgress(
                cardID: "p1",
                orderIndex: 1,
                sound: "a",
                word: "cat",
                deckState: .currentDeck,
                masteryCorrectCount: 2
            )
        )
        try? ctx.save()
        container = c
    }

    var body: some View {
        FlashCardStudyView(session: session)
            .modelContainer(container)
    }
}
