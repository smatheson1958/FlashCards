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
    @Bindable private var appearance = StudyAppearanceSettings.shared
    /// True while bundled JSON is imported into SwiftData on first launch.
    var isLibraryPreparing: Bool = false
    /// When true, begins a session as soon as the library is ready (skips the Study / Start session screen).
    var autoStartOnAppear: Bool = false

    @State private var showingBack = false
    @State private var dragOffset: CGSize = .zero
    @State private var flipDegrees: Double = 0
    @State private var isBuildingSession = false
    @State private var showEmptyDeckAlert = false
    @State private var segmentationSound = SegmentationSoundPlayer()
    @State private var wordAudio = WordAudioPlayer()
    @State private var tapFlipSequenceTask: Task<Void, Never>?
    @State private var autoPlayWordTask: Task<Void, Never>?
    /// After the word WAV has played once on the back, any tap on the card replays it.
    @State private var wordSoundHeardThisBack = false
    /// While waiting for auto-play: countdown phase for `StandardDelayCountdownIndicator` (0…tick count).
    @State private var wordAutoPlayCountdownPhase = 0

    private let swipeThreshold: CGFloat = 96
    /// Pause after tap, before playing the letter sound.
    private let tapPauseBeforeSound: TimeInterval = 0.5
    /// Pause after the sound ends, before flipping the card.
    private let tapPauseAfterSoundBeforeFlip: TimeInterval = 0.5

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
                    .onChange(of: showingBack) { _, isBack in
                        if isBack {
                            wordSoundHeardThisBack = false
                        }
                        scheduleAutoPlayWordAfterFlip(isBack: isBack, card: card)
                    }
            } else if isBuildingSession {
                buildingSessionView
            } else if session.started {
                ContentUnavailableView("No cards", systemImage: "rectangle.stack")
            } else {
                startPrompt
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(appearance.backgroundColor)
        .animation(.spring(duration: 0.45, bounce: 0.22), value: showingBack)
        .animation(.spring(duration: 0.45, bounce: 0.22), value: flipDegrees)
        .onChange(of: session.currentEntry?.id) { _, _ in
            tapFlipSequenceTask?.cancel()
            tapFlipSequenceTask = nil
            autoPlayWordTask?.cancel()
            autoPlayWordTask = nil
            isBuildingSession = false
            showingBack = false
            flipDegrees = 0
            dragOffset = .zero
            wordSoundHeardThisBack = false
            wordAutoPlayCountdownPhase = 0
            wordAudio.clearPlaybackWarning()
        }
        .onChange(of: session.started) { _, started in
            if !started {
                isBuildingSession = false
                tapFlipSequenceTask?.cancel()
                tapFlipSequenceTask = nil
                autoPlayWordTask?.cancel()
                autoPlayWordTask = nil
                wordAutoPlayCountdownPhase = 0
            }
        }
        .onDisappear {
            tapFlipSequenceTask?.cancel()
            tapFlipSequenceTask = nil
            autoPlayWordTask?.cancel()
            autoPlayWordTask = nil
            wordAutoPlayCountdownPhase = 0
        }
        .alert("Nothing to study", isPresented: $showEmptyDeckAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("There are no cards in your current deck yet. Open the Current deck tab after the library finishes loading, or delete and reinstall if setup didn’t complete.")
        }
        .task(id: isLibraryPreparing) {
            guard autoStartOnAppear else { return }
            guard !isLibraryPreparing else { return }
            guard !session.started else { return }
            beginSession()
        }
    }

    private var libraryPreparingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.25)
                .tint(appearance.surroundColor)
            Text("Building your library…")
                .font(appearance.bodyFont(size: 17, weight: .semibold))
            Text("Loading sounds and cards from the bundled reference files. This only runs once.")
                .font(appearance.bodyFont(size: 15))
                .foregroundStyle(appearance.surroundColor.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding()
    }

    private var buildingSessionView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(appearance.surroundColor)
            Text("Preparing your session…")
                .font(appearance.bodyFont(size: 17, weight: .semibold))
            Text("Shuffling the current deck and review cards.")
                .font(appearance.bodyFont(size: 15))
                .foregroundStyle(appearance.surroundColor.opacity(0.85))
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
                description: Text("Start a session to practise sounds. Tap the card for the sound, then it flips; swipe right for correct or left for wrong.")
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

    @ViewBuilder
    private func progressHint(card: CardProgress, isReview: Bool) -> some View {
        HStack {
            if isReview {
                Text("Review")
                    .font(appearance.bodyFont(size: 12, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(appearance.surroundColor.opacity(0.35), in: Capsule())
                    .foregroundStyle(appearance.primaryTextColor.opacity(0.9))
            }
            Spacer()
            if !isReview {
                Text("\(card.masteryCorrectCount)/\(FlashCardsConstants.masteryThreshold)")
                    .font(appearance.bodyFont(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(appearance.surroundColor.opacity(0.9))
            }
        }
        .padding(.horizontal, 24)
    }

    /// Tap strips at the card edges + arrow visuals when the answer face is visible (left = wrong, right = correct).
    private var cardEdgeSwipeOverlay: some View {
        ZStack {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let side = min(max(w * 0.26, 72), 130)
                HStack(spacing: 0) {
                    Button {
                        commitSwipe(correct: false)
                    } label: {
                        Color.clear
                            .frame(width: side, height: h)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Wrong")
                    .accessibilityHint("Same as swiping left.")

                    Color.clear
                        .frame(width: max(w - 2 * side, 0), height: h)
                        .allowsHitTesting(false)

                    Button {
                        commitSwipe(correct: true)
                    } label: {
                        Color.clear
                            .frame(width: side, height: h)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Correct")
                    .accessibilityHint("Same as swiping right.")
                }
                .frame(width: w, height: h)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            cardEdgeSwipeArrowIcons
                .allowsHitTesting(false)
        }
    }

    private var cardEdgeSwipeArrowIcons: some View {
        let w = dragOffset.width
        let dragBias: CGFloat = 14
        let wrongTint = Color(red: 0.78, green: 0.22, blue: 0.24)
        let correctTint = Color(red: 0.18, green: 0.55, blue: 0.34)
        return HStack {
            swipeEdgeArrow(
                systemImage: "arrow.left",
                accent: wrongTint,
                emphasized: w < -dragBias,
                dimmed: w > dragBias
            )
            Spacer(minLength: 0)
            swipeEdgeArrow(
                systemImage: "arrow.right",
                accent: correctTint,
                emphasized: w > dragBias,
                dimmed: w < -dragBias
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 8)
        .animation(.easeOut(duration: 0.14), value: w)
        .accessibilityHidden(true)
    }

    private func swipeEdgeArrow(systemImage: String, accent: Color, emphasized: Bool, dimmed: Bool) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 28, weight: .semibold))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(accent)
            .opacity(dimmed ? 0.38 : (emphasized ? 1 : 0.82))
            .scaleEffect(emphasized ? 1.07 : 1)
    }

    private func cardFace(card: CardProgress, isReview: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(appearance.cardFillColor)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(appearance.surroundColor.opacity(0.45), lineWidth: 1.5)
                }
                .shadow(color: appearance.surroundColor.opacity(0.25), radius: 12, y: 6)

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

            if showingBack {
                cardEdgeSwipeOverlay
            }
        }
        .frame(maxWidth: 520)
        .frame(minHeight: 280)
        .contentShape(Rectangle())
        .offset(dragOffset)
        .onTapGesture {
            if showingBack {
                guard wordSoundHeardThisBack else { return }
                playWordAudio(card: card)
                return
            }
            tapFlipSequenceTask?.cancel()
            tapFlipSequenceTask = Task { @MainActor in
                let preNs = UInt64((tapPauseBeforeSound * 1_000_000_000.0).rounded())
                try? await Task.sleep(nanoseconds: preNs)
                guard !Task.isCancelled else { return }
                await segmentationSound.playGraphemeOrBeepAwaitFinish(card.sound)
                guard !Task.isCancelled else { return }
                let postNs = UInt64((tapPauseAfterSoundBeforeFlip * 1_000_000_000.0).rounded())
                try? await Task.sleep(nanoseconds: postNs)
                guard !Task.isCancelled else { return }
                withAnimation(.spring(duration: 0.5, bounce: 0.18)) {
                    showingBack.toggle()
                    flipDegrees = showingBack ? 180 : 0
                }
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

    private func scheduleAutoPlayWordAfterFlip(isBack: Bool, card: CardProgress) {
        autoPlayWordTask?.cancel()
        autoPlayWordTask = nil
        wordAutoPlayCountdownPhase = 0
        guard isBack else { return }
        autoPlayWordTask = Task { @MainActor in
            wordAutoPlayCountdownPhase = 0
            let nanosPerTick = FlashCardsConstants.StandardDelay.nanosecondsPerTick
            for tick in 1...FlashCardsConstants.StandardDelay.tickCount {
                do {
                    try await Task.sleep(nanoseconds: nanosPerTick)
                } catch {
                    wordAutoPlayCountdownPhase = 0
                    return
                }
                guard !Task.isCancelled else {
                    wordAutoPlayCountdownPhase = 0
                    return
                }
                withAnimation(.easeInOut(duration: 0.2)) {
                    wordAutoPlayCountdownPhase = tick
                }
            }
            guard !Task.isCancelled else {
                wordAutoPlayCountdownPhase = 0
                return
            }
            playWordAudio(card: card)
        }
    }

    private func playWordAudio(card: CardProgress) {
        autoPlayWordTask?.cancel()
        autoPlayWordTask = nil
        wordAutoPlayCountdownPhase = FlashCardsConstants.StandardDelay.tickCount
        let stem = card.word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        wordAudio.play(stem: stem)
        wordSoundHeardThisBack = true
    }

    private func commitSwipe(correct: Bool) {
        autoPlayWordTask?.cancel()
        autoPlayWordTask = nil
        wordAutoPlayCountdownPhase = 0
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
                .font(appearance.bodyFont(size: 12))
                .foregroundStyle(appearance.surroundColor.opacity(0.85))
            Text(card.sound)
                .font(appearance.titleFont(size: 72, weight: .medium))
                .foregroundStyle(appearance.primaryTextColor)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text("Tap — pause, sound, then flip")
                .font(appearance.bodyFont(size: 13))
                .foregroundStyle(appearance.surroundColor.opacity(0.65))
                .multilineTextAlignment(.center)
        }
    }

    private func backContent(card: CardProgress) -> some View {
        VStack(spacing: 16) {
            Text("Word")
                .font(appearance.bodyFont(size: 12))
                .foregroundStyle(appearance.surroundColor.opacity(0.85))
            backWordText(card: card)
            cardImage(card: card)
            // Stays visible after the countdown and word audio; all dots lit once complete.
            StandardDelayCountdownIndicator(
                phase: wordAutoPlayCountdownPhase,
                activeColor: appearance.primaryTextColor,
                dotDiameter: 10,
                inactiveOpacity: 0.38,
                accessibilityDescription: "Seconds until word audio"
            )
            .padding(.top, 10)
        }
    }

    @ViewBuilder
    private func backWordText(card: CardProgress) -> some View {
        let text = Text(card.word.capitalized)
            .font(appearance.titleFont(size: 44, weight: .semibold))
            .foregroundStyle(appearance.primaryTextColor)
            .multilineTextAlignment(.center)
        if wordSoundHeardThisBack {
            text
        } else {
            text
                .contentShape(Rectangle())
                .highPriorityGesture(
                    TapGesture().onEnded {
                        playWordAudio(card: card)
                    }
                )
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
