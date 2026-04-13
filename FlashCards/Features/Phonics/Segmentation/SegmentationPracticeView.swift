//
//  SegmentationPracticeView.swift
//  FlashCards
//

import SwiftData
import SwiftUI
import UIKit

/// Hear segment sounds and the whole word; segments come from `segmentation.json` first, then the G1 index / construction seed.
struct SegmentationModeView: View {
    let word: String
    let segments: [String]
    /// Matches `ConstructionIndexG1ItemDTO.id` / Sound Card `orderIndex` when opened from phonics; `nil` uses flat `WordsAudio/<stem>.wav` only.
    var soundOrderIndex: Int?
    var isReminderSession: Bool
    var dismissAfterRecordingSuccess: Bool
    /// Journey / error fallback: learner indicates a miss without recording success (module-local only).
    var showPracticeMissButton: Bool
    var onSuccessfulPracticeRecorded: (() -> Void)?
    var onPracticeMissed: (() -> Void)?
    var onReminderMissed: (() -> Void)?

    @Bindable private var appearance = StudyAppearanceSettings.shared
    @Environment(\.dismiss) private var dismiss

    @State private var segmentPlayer = SegmentationSoundPlayer()
    @State private var wordPlayer = WordAudioPlayer()
    @State private var didPlayWholeWord = false
    @State private var playedSegmentIndices: Set<Int> = []
    @State private var didRecordSuccessThisVisit = false

    init(
        word: String,
        segments: [String],
        soundOrderIndex: Int? = nil,
        isReminderSession: Bool = false,
        dismissAfterRecordingSuccess: Bool = true,
        showPracticeMissButton: Bool = false,
        onSuccessfulPracticeRecorded: (() -> Void)? = nil,
        onPracticeMissed: (() -> Void)? = nil,
        onReminderMissed: (() -> Void)? = nil
    ) {
        self.word = word
        self.segments = segments
        self.soundOrderIndex = soundOrderIndex
        self.isReminderSession = isReminderSession
        self.dismissAfterRecordingSuccess = dismissAfterRecordingSuccess
        self.showPracticeMissButton = showPracticeMissButton
        self.onSuccessfulPracticeRecorded = onSuccessfulPracticeRecorded
        self.onPracticeMissed = onPracticeMissed
        self.onReminderMissed = onReminderMissed
    }

    private var canRecordSuccess: Bool {
        didPlayWholeWord && playedSegmentIndices.count == segments.count && segments.count > 0 && !didRecordSuccessThisVisit
    }

    var body: some View {
        VStack(spacing: 36) {
            Spacer(minLength: 0)

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                segmentPlayer.stop()
                let stem = ConstructionDataSource.normalizedWordKey(word)
                wordPlayer.play(stem: stem, soundOrderIndex: soundOrderIndex)
                didPlayWholeWord = true
            } label: {
                Text(ConstructionDataSource.normalizedWordKey(word).uppercased())
                    .font(appearance.titleFont(size: 40, weight: .semibold))
                    .foregroundStyle(appearance.primaryTextColor)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .padding(.horizontal, 24)
                    .background(appearance.cardFillColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(appearance.surroundColor.opacity(0.4), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Whole word, \(word)")

            HStack(spacing: 12) {
                ForEach(segments.indices, id: \.self) { index in
                    let segment = segments[index]
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        wordPlayer.stop()
                        segmentPlayer.playGrapheme(segment)
                        _ = playedSegmentIndices.insert(index)
                    } label: {
                        Text(segment.uppercased())
                            .font(appearance.titleFont(size: 26, weight: .semibold))
                            .foregroundStyle(appearance.primaryTextColor)
                            .frame(minWidth: 44, minHeight: 56)
                            .padding(.horizontal, 14)
                            .background(appearance.cardFillColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(appearance.surroundColor.opacity(0.35), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Segment \(segment)")
                }
            }
            .frame(maxWidth: .infinity)

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onSuccessfulPracticeRecorded?()
                didRecordSuccessThisVisit = true
                if dismissAfterRecordingSuccess {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        dismiss()
                    }
                }
            } label: {
                Text("Record successful practice")
                    .font(appearance.bodyFont(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canRecordSuccess)

            Text("Listen to the whole word, then each segment at least once. Then tap the button above to count one success toward five.")
                .font(appearance.bodyFont(size: 13))
                .foregroundStyle(appearance.primaryTextColor.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            if isReminderSession {
                Button(role: .destructive) {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    onReminderMissed?()
                    dismiss()
                } label: {
                    Text("Missed reminder — reset progress")
                        .font(appearance.bodyFont(size: 15, weight: .medium))
                }
                .buttonStyle(.bordered)
            }

            if showPracticeMissButton, let onPracticeMissed {
                Button(role: .destructive) {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    onPracticeMissed()
                } label: {
                    Text("Record miss (repeat pair)")
                        .font(appearance.bodyFont(size: 15, weight: .medium))
                }
                .buttonStyle(.bordered)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(appearance.backgroundColor)
    }
}

/// Entry from **Exercises**: word-first list (classic segmentation flow), plus “Browse by sound” for the grouped list.
struct SegmentationPracticeListView: View {
    var body: some View {
        SegmentationExerciseHubView()
            .navigationTitle("Segmentation")
            .navigationBarTitleDisplayMode(.inline)
            .studyAppearanceToolbar()
    }
}

// MARK: - Hub (words) + optional sound browser

/// One visit’s two-word pair for the hub list (opens `SegmentationVisitPairPracticeView`).
private struct SegmentationHubPairRow: Identifiable, Hashable {
    let id: String
    let soundLabel: String
    let orderIndex: Int
    let visitIndex: Int
    let word0: String
    let word1: String
    let segments0: [String]
    let segments1: [String]
}

private struct SegmentationExerciseHubView: View {
    @Bindable private var appearance = StudyAppearanceSettings.shared

    @Query(
        filter: #Predicate<CardProgress> { card in
            card.deckStateRaw != "notIntroduced" && card.masteryCorrectCount >= 3
        },
        sort: \CardProgress.orderIndex
    )
    private var qualifyingSoundCards: [CardProgress]

    @Query(sort: \ModeWordProgress.progressID)
    private var allModeProgress: [ModeWordProgress]

    private var workingSounds: [CardProgress] {
        let cap = FlashCardsConstants.currentDeckTargetCount
        let slice = Array(qualifyingSoundCards.prefix(cap))
        return slice.filter { card in
            let snap = SoundCardProgressSnapshot(card: card)
            return LearningProgressionEngine.isSegmentationUnlocked(snap)
        }
    }

    /// Visit pairs from the journey seed (or synthetic pairs); both words must have segmentation data.
    private var hubPairRows: [SegmentationHubPairRow] {
        var rows: [SegmentationHubPairRow] = []
        rows.reserveCapacity(workingSounds.count * 5)
        for card in workingSounds {
            let pairs = SegmentationJourneyLoader.fiveVisitWordPairs(soundOrderIndex: card.orderIndex)
            for p in pairs {
                let s0 = SegmentationDataSource.resolvedSegments(forWord: p.word0, soundOrderIndex: card.orderIndex)
                let s1 = SegmentationDataSource.resolvedSegments(forWord: p.word1, soundOrderIndex: card.orderIndex)
                guard !s0.isEmpty, !s1.isEmpty else { continue }
                rows.append(
                    SegmentationHubPairRow(
                        id: "\(card.orderIndex)|visit\(p.visitIndex)",
                        soundLabel: card.sound,
                        orderIndex: card.orderIndex,
                        visitIndex: p.visitIndex,
                        word0: p.word0,
                        word1: p.word1,
                        segments0: s0,
                        segments1: s1
                    )
                )
            }
        }
        return rows
    }

    private var segmentationReminders: [ModeWordProgress] {
        let cap = FlashCardsConstants.modeExerciseWordMasteryCount
        return allModeProgress.filter { row in
            row.mode == .segmentation && row.correctCountTowardMastery >= cap
        }
        .sorted { $0.progressID < $1.progressID }
    }

    var body: some View {
        Group {
            if hubPairRows.isEmpty && segmentationReminders.isEmpty {
                ContentUnavailableView(
                    "No segmentation yet",
                    systemImage: "rectangle.split.3x1",
                    description: Text(
                        "Get at least \(FlashCardsConstants.constructionSegmentationMinSoundCardCorrect) correct swipes on Sound Cards for a sound (and introduce it), then words appear here. Use Browse by sound (when unlocked) for the grouped list."
                    )
                )
            } else {
                List {
                    Section {
                        Text(
                            "The journey follows bundled visit pairs (five per sound) when available. Below, each sound lists visits with per-word progress."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                    }

                    Section {
                        NavigationLink {
                            SegmentationJourneySessionView()
                        } label: {
                            Label("Segmentation journey", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                                .font(appearance.bodyFont(size: 17, weight: .semibold))
                        }
                        Text("Unlocked sounds only, visit order 1 → 5, two words per visit. Errors adjust this sound’s module progress only.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("Guided path")
                    }

                    Section {
                        Text(
                            "Each row is one visit for a sound. The two practice words open in order; then you return here."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                    }

                    if !hubPairRows.isEmpty {
                        Section("Sounds") {
                            ForEach(hubPairRows) { row in
                                NavigationLink {
                                    SegmentationVisitPairPracticeView(
                                        soundOrderIndex: row.orderIndex,
                                        visitIndex: row.visitIndex,
                                        word0: row.word0,
                                        word1: row.word1,
                                        segments0: row.segments0,
                                        segments1: row.segments1
                                    )
                                } label: {
                                    HStack(alignment: .center, spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Sound \(row.soundLabel)")
                                                .font(appearance.bodyFont(size: 17, weight: .semibold))
                                            Text("Visit \(row.visitIndex)")
                                                .font(appearance.bodyFont(size: 13, weight: .medium))
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer(minLength: 8)
                                        HStack(spacing: 8) {
                                            SegmentationHubFiveBoxes(
                                                filledCount: segmentationProgressCount(
                                                    soundOrderIndex: row.orderIndex,
                                                    word: row.word0
                                                )
                                            )
                                            SegmentationHubFiveBoxes(
                                                filledCount: segmentationProgressCount(
                                                    soundOrderIndex: row.orderIndex,
                                                    word: row.word1
                                                )
                                            )
                                        }
                                    }
                                    .accessibilityLabel(
                                        "Sound \(row.soundLabel), visit \(row.visitIndex). Words \(row.word0) and \(row.word1)."
                                    )
                                }
                            }
                        }
                    }

                    if !segmentationReminders.isEmpty {
                        Section("Reminders (mastered words)") {
                            ForEach(segmentationReminders, id: \.progressID) { row in
                                segmentationReminderRow(row: row)
                            }
                        }
                    }

                    Section {
                        NavigationLink {
                            PhonicsModeSoundListView(mode: .segmentation, chrome: .embeddedSoundBrowser)
                        } label: {
                            Label("Browse by sound", systemImage: "list.bullet.indent")
                                .font(appearance.bodyFont(size: 16, weight: .medium))
                        }
                    } header: {
                        Text("More")
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(appearance.backgroundColor)
    }

    @ViewBuilder
    private func segmentationReminderRow(row: ModeWordProgress) -> some View {
        let word = row.wordKey
        let segments = SegmentationDataSource.resolvedSegments(forWord: word, soundOrderIndex: row.soundOrderIndex)
        if segments.isEmpty {
            Text(word.capitalized)
                .font(appearance.bodyFont(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        } else {
            NavigationLink {
                PhonicsModeWordSessionView(
                    mode: .segmentation,
                    soundOrderIndex: row.soundOrderIndex,
                    word: word,
                    segments: segments,
                    isReminder: true
                )
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(word.capitalized)
                        .font(appearance.bodyFont(size: 17, weight: .medium))
                    Text("Sound #\(row.soundOrderIndex) · reminder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func segmentationProgressCount(soundOrderIndex: Int, word: String) -> Int {
        let key = ModeWordProgressService.normalizedWordKey(word)
        if let row = allModeProgress.first(where: {
            $0.soundOrderIndex == soundOrderIndex && $0.mode == .segmentation && $0.wordKey == key
        }) {
            return row.correctCountTowardMastery
        }
        return 0
    }
}

private struct SegmentationHubFiveBoxes: View {
    let filledCount: Int

    private static let boxSize: CGFloat = 10
    private static let boxSpacing: CGFloat = 3

    private var cap: Int { FlashCardsConstants.modeExerciseWordMasteryCount }

    var body: some View {
        HStack(spacing: Self.boxSpacing) {
            ForEach(0..<cap, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(index < filledCount ? Color.green : Color.clear)
                    .frame(width: Self.boxSize, height: Self.boxSize)
                    .overlay {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                    }
            }
        }
        .accessibilityLabel("\(min(filledCount, cap)) of \(cap) for this word")
    }
}

#Preview("Segmentation list") {
    let schema = Schema([
        CardProgress.self,
        ModeWordProgress.self,
        SegmentationSoundModuleProgress.self,
        SegmentationProgressEvent.self,
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: config)
    return NavigationStack {
        SegmentationPracticeListView()
    }
    .modelContainer(container)
}

#Preview("Segmentation word") {
    NavigationStack {
        SegmentationModeView(word: "cat", segments: ["c", "a", "t"])
            .studyAppearanceToolbar()
    }
}
