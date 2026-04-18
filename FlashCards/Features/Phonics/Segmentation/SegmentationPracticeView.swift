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

private enum SegmentationExerciseHubConfig {
    /// One recorded success completes that word for the hub (solid green square). Revisit flow may use counts later.
    static let successesPerHubWord = 1
}

/// One sound’s visit pairs for the hub list (opens `SegmentationVisitPairPracticeView` at the next incomplete visit).
private struct SegmentationHubSoundRow: Identifiable, Hashable {
    let id: String
    let soundLabel: String
    let orderIndex: Int
    let visitPairs: [SegmentationHubVisitPair]
}

private struct SegmentationHubVisitPair: Hashable {
    let visitIndex: Int
    let word0: String
    let word1: String
    let segments0: [String]
    let segments1: [String]
}

private func hubTenWordsWithSegments(for row: SegmentationHubSoundRow) -> [(word: String, segments: [String])] {
    var out: [(word: String, segments: [String])] = []
    out.reserveCapacity(row.visitPairs.count * 2)
    for p in row.visitPairs {
        out.append((word: p.word0, segments: p.segments0))
        out.append((word: p.word1, segments: p.segments1))
    }
    return out
}

/// Two distinct words from the hub’s list, in random order, for a no-progress review session.
private func pickRandomHubReviewPair(from row: SegmentationHubSoundRow) -> (word0: String, segments0: [String], word1: String, segments1: [String])? {
    let items = hubTenWordsWithSegments(for: row)
    guard items.count >= 2 else { return nil }
    let i = Int.random(in: 0..<items.count)
    var j = Int.random(in: 0..<items.count)
    while j == i {
        j = Int.random(in: 0..<items.count)
    }
    var pair = [items[i], items[j]]
    pair.shuffle()
    return (pair[0].word, pair[0].segments, pair[1].word, pair[1].segments)
}

/// After all ten hub words are done, opens a random two-word pair without recording progress.
private struct SegmentationHubReviewPairSessionView: View {
    let row: SegmentationHubSoundRow

    @State private var picked: (word0: String, segments0: [String], word1: String, segments1: [String])?

    var body: some View {
        Group {
            if hubTenWordsWithSegments(for: row).count < 2 {
                ContentUnavailableView(
                    "Review unavailable",
                    systemImage: "rectangle.split.3x1",
                    description: Text("This sound needs at least two practice words for a random pair.")
                )
            } else if let picked {
                SegmentationVisitPairPracticeView(
                    soundOrderIndex: row.orderIndex,
                    visitIndex: 0,
                    word0: picked.word0,
                    word1: picked.word1,
                    segments0: picked.segments0,
                    segments1: picked.segments1,
                    recordsProgress: false,
                    isReviewSession: true
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task {
                        picked = pickRandomHubReviewPair(from: row)
                    }
            }
        }
    }
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

    /// One row per sound: five visit pairs (when all have segments), merged progress in the list cell.
    private var hubSoundRows: [SegmentationHubSoundRow] {
        var rows: [SegmentationHubSoundRow] = []
        rows.reserveCapacity(workingSounds.count)
        for card in workingSounds {
            let pairs = SegmentationJourneyLoader.fiveVisitWordPairs(soundOrderIndex: card.orderIndex)
            var visitPairs: [SegmentationHubVisitPair] = []
            visitPairs.reserveCapacity(pairs.count)
            for p in pairs {
                let s0 = SegmentationDataSource.resolvedSegments(forWord: p.word0, soundOrderIndex: card.orderIndex)
                let s1 = SegmentationDataSource.resolvedSegments(forWord: p.word1, soundOrderIndex: card.orderIndex)
                guard !s0.isEmpty, !s1.isEmpty else { continue }
                visitPairs.append(
                    SegmentationHubVisitPair(
                        visitIndex: p.visitIndex,
                        word0: p.word0,
                        word1: p.word1,
                        segments0: s0,
                        segments1: s1
                    )
                )
            }
            guard !visitPairs.isEmpty else { continue }
            rows.append(
                SegmentationHubSoundRow(
                    id: "\(card.orderIndex)",
                    soundLabel: card.sound,
                    orderIndex: card.orderIndex,
                    visitPairs: visitPairs
                )
            )
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
            if hubSoundRows.isEmpty && segmentationReminders.isEmpty {
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
                            "The journey follows bundled visit pairs (five per sound) when available. Below, each sound shows merged progress for all visits."
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
                            "Each row is one sound. Tap to open the next incomplete visit; the two practice words run in order, then you return here. Ten squares: one per word (two per visit). One successful practice fills that square green. When all ten are green, tap the row for a random two-word review (no extra progress recorded)."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                    }

                    if !hubSoundRows.isEmpty {
                        Section("Sounds") {
                            ForEach(hubSoundRows) { row in
                                if hubSoundIsFullyComplete(for: row) {
                                    NavigationLink {
                                        SegmentationHubReviewPairSessionView(row: row)
                                    } label: {
                                        hubSoundRowLabel(row: row)
                                    }
                                } else {
                                    NavigationLink {
                                        segmentationHubPairPracticeDestination(for: row)
                                    } label: {
                                        hubSoundRowLabel(row: row)
                                    }
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
    private func hubSoundRowLabel(row: SegmentationHubSoundRow) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Sound \(row.soundLabel)")
                .font(appearance.bodyFont(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 4) {
                ForEach(Array(hubWordCompletionFlags(for: row).enumerated()), id: \.offset) { _, isDone in
                    SegmentationHubWordProgressSquare(isCompleted: isDone)
                }
            }
        }
        .accessibilityLabel(accessibilityLabelForHubSoundRow(row))
    }

    private func hubSoundIsFullyComplete(for row: SegmentationHubSoundRow) -> Bool {
        let flags = hubWordCompletionFlags(for: row)
        return !flags.isEmpty && flags.allSatisfy { $0 }
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

    /// Visit order: for each visit, first word then second word (ten flags when five visits are present).
    private func hubWordCompletionFlags(for row: SegmentationHubSoundRow) -> [Bool] {
        let need = SegmentationExerciseHubConfig.successesPerHubWord
        var flags: [Bool] = []
        flags.reserveCapacity(row.visitPairs.count * 2)
        for p in row.visitPairs {
            flags.append(segmentationProgressCount(soundOrderIndex: row.orderIndex, word: p.word0) >= need)
            flags.append(segmentationProgressCount(soundOrderIndex: row.orderIndex, word: p.word1) >= need)
        }
        return flags
    }

    @ViewBuilder
    private func segmentationHubPairPracticeDestination(for row: SegmentationHubSoundRow) -> some View {
        let pair = defaultHubVisitPair(for: row)
        SegmentationVisitPairPracticeView(
            soundOrderIndex: row.orderIndex,
            visitIndex: pair.visitIndex,
            word0: pair.word0,
            word1: pair.word1,
            segments0: pair.segments0,
            segments1: pair.segments1
        )
    }

    /// First visit where either word has not yet completed the hub (one success); otherwise the first visit so practice can still be opened.
    private func defaultHubVisitPair(for row: SegmentationHubSoundRow) -> SegmentationHubVisitPair {
        let need = SegmentationExerciseHubConfig.successesPerHubWord
        for p in row.visitPairs {
            let c0 = segmentationProgressCount(soundOrderIndex: row.orderIndex, word: p.word0)
            let c1 = segmentationProgressCount(soundOrderIndex: row.orderIndex, word: p.word1)
            if c0 < need || c1 < need { return p }
        }
        return row.visitPairs[0]
    }

    private func accessibilityLabelForHubSoundRow(_ row: SegmentationHubSoundRow) -> String {
        let need = SegmentationExerciseHubConfig.successesPerHubWord
        var parts: [String] = []
        parts.reserveCapacity(row.visitPairs.count)
        var squareIndex = 1
        for p in row.visitPairs {
            let c0 = segmentationProgressCount(soundOrderIndex: row.orderIndex, word: p.word0)
            let c1 = segmentationProgressCount(soundOrderIndex: row.orderIndex, word: p.word1)
            let d0 = c0 >= need ? "done" : "not done"
            let d1 = c1 >= need ? "done" : "not done"
            parts.append(
                "Visit \(p.visitIndex): \(p.word0) \(d0), \(p.word1) \(d1); squares \(squareIndex)–\(squareIndex + 1)"
            )
            squareIndex += 2
        }
        let reviewHint = hubSoundIsFullyComplete(for: row)
            ? " All words complete. Tap for a random two-word review."
            : ""
        return "Sound \(row.soundLabel). " + parts.joined(separator: ". ") + "." + reviewHint
    }
}

/// One small square per word: solid green when that word has at least one recorded success for the hub.
private struct SegmentationHubWordProgressSquare: View {
    let isCompleted: Bool

    private static let boxSize: CGFloat = 12

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(isCompleted ? Color.green : Color.clear)
            .frame(width: Self.boxSize, height: Self.boxSize)
            .overlay {
                if !isCompleted {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                }
            }
            .accessibilityLabel(isCompleted ? "Word completed" : "Word not completed")
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
