//
//  PhonicsModeSoundListView.swift
//  FlashCards
//
//  Working sounds (Sound Cards ≥ 3 correct, up to `FlashCardsConstants.currentDeckTargetCount`) with stage‑4 words from `construction_index_g1_foundation.json`,
//  per‑word five‑box progress, and reminders for words mastered in this mode.
//

import SwiftData
import SwiftUI

/// How `PhonicsModeSoundListView` presents chrome when embedded inside another screen (e.g. Segmentation hub).
enum PhonicsModeSoundListChrome: Sendable {
    /// Standalone tab / exercise: full title and appearance toolbar.
    case standalone
    /// Pushed from a hub: own title “By sound”, toolbar; no duplicate root title.
    case embeddedSoundBrowser
}

struct PhonicsModeSoundListView: View {
    let mode: PhonicsModeExerciseKind
    var chrome: PhonicsModeSoundListChrome = .standalone

    @Environment(\.modelContext) private var modelContext
    @Bindable private var appearance = StudyAppearanceSettings.shared

    @AppStorage(FlashCardsConstants.userDefaultsKeyDebugAdjustProgressSquares)
    private var debugAdjustProgressSquares = false

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
        let learningMode: LearningPracticeMode = mode == .construction ? .construction : .segmentation
        return slice.filter { card in
            let snap = SoundCardProgressSnapshot(card: card)
            return learningMode == .construction
                ? LearningProgressionEngine.isConstructionUnlocked(snap)
                : LearningProgressionEngine.isSegmentationUnlocked(snap)
        }
    }

    private var reminderRows: [ModeWordProgress] {
        let cap = FlashCardsConstants.modeExerciseWordMasteryCount
        return allModeProgress.filter { row in
            row.mode == mode && row.correctCountTowardMastery >= cap
        }
        .sorted { $0.progressID < $1.progressID }
    }

    private var navigationTitle: String {
        switch chrome {
        case .standalone:
            return mode == .construction ? "Construction" : "Segmentation"
        case .embeddedSoundBrowser:
            return "By sound"
        }
    }

    private var introFootnote: String {
        switch chrome {
        case .standalone:
            return "Up to \(FlashCardsConstants.currentDeckTargetCount) sounds with enough Sound Card practice. Each sound lists the first five words from stage 4 when the foundation construction index includes that sound (typically sounds 1–30); otherwise the curriculum example word is used. Segmentation uses `segmentation.json` when a word is listed there; otherwise the same grapheme path as construction."
        case .embeddedSoundBrowser:
            return "Expand a sound to open a word, or go back and pick a word from the main list."
        }
    }

    var body: some View {
        Group {
            if workingSounds.isEmpty && reminderRows.isEmpty {
                ContentUnavailableView(
                    "No \(mode == .construction ? "construction" : "segmentation") yet",
                    systemImage: mode == .construction ? "square.grid.3x3" : "rectangle.split.3x1",
                    description: Text(
                        "Get at least \(FlashCardsConstants.constructionSegmentationMinSoundCardCorrect) correct swipes on Sound Cards for a sound (and introduce it), then the first five stage‑4 words appear here."
                    )
                )
            } else {
                List {
                    Section {
                        Text(introFootnote)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                    }

                    if !workingSounds.isEmpty {
                        Section("Working sounds") {
                            ForEach(workingSounds, id: \.cardID) { card in
                                soundDisclosureGroup(card: card)
                            }
                        }
                    }

                    if !reminderRows.isEmpty {
                        Section("Reminders (mastered words)") {
                            ForEach(reminderRows, id: \.progressID) { row in
                                reminderLink(row: row)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(appearance.backgroundColor)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .studyAppearanceToolbar()
    }

    @ViewBuilder
    private func soundDisclosureGroup(card: CardProgress) -> some View {
        let snap = SoundCardProgressSnapshot(card: card)
        let learningMode: LearningPracticeMode = mode == .construction ? .construction : .segmentation
        let words = LearningProgressionEngine.wordsForMode(
            orderIndex: card.orderIndex,
            mode: learningMode,
            snapshot: snap
        )
        DisclosureGroup {
            if words.isEmpty {
                Text("No words in programme for this sound.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(words, id: \.self) { word in
                    wordRow(card: card, word: word, curriculumWords: words)
                }
            }
        } label: {
            HStack {
                Text(card.sound)
                    .font(appearance.bodyFont(size: 17, weight: .semibold))
                Text("·")
                    .foregroundStyle(.tertiary)
                Text("\(card.masteryCorrectCount)/\(FlashCardsConstants.masteryThreshold) sound")
                    .font(appearance.bodyFont(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func segmentsForWord(card: CardProgress, word: String) -> [String] {
        if mode == .segmentation {
            return SegmentationDataSource.resolvedSegments(forWord: word, soundOrderIndex: card.orderIndex)
        }
        return ConstructionIndexG1Loader.graphemeUnits(forSoundOrderIndex: card.orderIndex, word: word)
            ?? ConstructionDataSource.segments(forWord: word)
    }

    private func isWordExerciseOpenable(card: CardProgress, word: String) -> Bool {
        let segments = segmentsForWord(card: card, word: word)
        if mode == .segmentation { return !segments.isEmpty }
        return segments.count >= FlashCardsConstants.constructionMinimumSegmentCount
    }

    /// Up to `phonicsWordsPerSoundDrillSession` consecutive openable words from the curriculum, starting at `startWord`.
    private func openableDrillWords(card: CardProgress, curriculumWords: [String], startWord: String) -> [String] {
        let start = curriculumWords.firstIndex(where: { $0.caseInsensitiveCompare(startWord) == .orderedSame }) ?? 0
        var out: [String] = []
        for w in curriculumWords.dropFirst(start) {
            guard isWordExerciseOpenable(card: card, word: w) else { continue }
            out.append(w)
            if out.count >= FlashCardsConstants.phonicsWordsPerSoundDrillSession { break }
        }
        return out
    }

    private func wordRow(card: CardProgress, word: String, curriculumWords: [String]) -> some View {
        let segments = segmentsForWord(card: card, word: word)
        let filled = modeProgressCount(soundOrderIndex: card.orderIndex, word: word)
        let canOpenExercise: Bool = {
            if mode == .segmentation { return !segments.isEmpty }
            return segments.count >= FlashCardsConstants.constructionMinimumSegmentCount
        }()

        return HStack(alignment: .center, spacing: 12) {
            if !canOpenExercise {
                Text(word.capitalized)
                    .font(appearance.bodyFont(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(mode == .construction ? "Too few pieces" : "No segments")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                let drillWords = openableDrillWords(card: card, curriculumWords: curriculumWords, startWord: word)
                NavigationLink {
                    PhonicsSoundWordDrillView(mode: mode, card: card, wordQueue: drillWords)
                } label: {
                    Text(word.capitalized)
                        .font(appearance.bodyFont(size: 16, weight: .medium))
                }
            }

            Spacer(minLength: 8)

            ModeExerciseFiveBoxes(
                filledCount: filled,
                onSquareTap: debugAdjustProgressSquares
                    ? { count in
                        ModeWordProgressService.setCorrectCountTowardMastery(
                            soundOrderIndex: card.orderIndex,
                            mode: mode,
                            word: word,
                            count: count,
                            context: modelContext
                        )
                    }
                    : nil
            )
        }
        .padding(.vertical, 4)
    }

    private func reminderLink(row: ModeWordProgress) -> some View {
        let word = row.wordKey
        let display = word.isEmpty ? row.wordKey : word
        let segments: [String] = {
            if mode == .segmentation {
                return SegmentationDataSource.resolvedSegments(forWord: word, soundOrderIndex: row.soundOrderIndex)
            }
            return ConstructionIndexG1Loader.graphemeUnits(forSoundOrderIndex: row.soundOrderIndex, word: word)
                ?? ConstructionDataSource.segments(forWord: word)
        }()
        let filled = row.correctCountTowardMastery
        let canOpenExercise: Bool = {
            if mode == .segmentation { return !segments.isEmpty }
            return segments.count >= FlashCardsConstants.constructionMinimumSegmentCount
        }()

        return HStack(spacing: 12) {
            if !canOpenExercise {
                VStack(alignment: .leading, spacing: 4) {
                    Text(display.capitalized)
                    Text("Sound #\(row.soundOrderIndex)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                NavigationLink {
                    PhonicsModeWordSessionView(
                        mode: mode,
                        soundOrderIndex: row.soundOrderIndex,
                        word: word,
                        segments: segments,
                        isReminder: true
                    )
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(display.capitalized)
                            .font(appearance.bodyFont(size: 16, weight: .medium))
                        Text("Sound #\(row.soundOrderIndex) · reminder")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 8)
            ModeExerciseFiveBoxes(
                filledCount: min(filled, FlashCardsConstants.modeExerciseWordMasteryCount),
                onSquareTap: debugAdjustProgressSquares
                    ? { count in
                        ModeWordProgressService.setCorrectCountTowardMastery(
                            soundOrderIndex: row.soundOrderIndex,
                            mode: mode,
                            word: row.wordKey,
                            count: count,
                            context: modelContext
                        )
                    }
                    : nil
            )
        }
    }

    private func modeProgressCount(soundOrderIndex: Int, word: String) -> Int {
        let key = ModeWordProgressService.normalizedWordKey(word)
        if let row = allModeProgress.first(where: {
            $0.soundOrderIndex == soundOrderIndex && $0.mode == mode && $0.wordKey == key
        }) {
            return row.correctCountTowardMastery
        }
        return 0
    }
}

// MARK: - Five-box indicator (mode word mastery)

private struct ModeExerciseFiveBoxes: View {
    let filledCount: Int
    /// When set (debug), tapping square *n* sets progress to *n* (1…cap).
    var onSquareTap: ((Int) -> Void)?

    private static let boxSize: CGFloat = 10
    private static let boxSpacing: CGFloat = 3

    private var cap: Int { FlashCardsConstants.modeExerciseWordMasteryCount }

    var body: some View {
        HStack(spacing: Self.boxSpacing) {
            ForEach(0..<cap, id: \.self) { index in
                let squareNumber = index + 1
                let filled = index < filledCount
                if let onSquareTap {
                    Button {
                        onSquareTap(squareNumber)
                    } label: {
                        modeSquareShape(filled: filled)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Set progress to \(squareNumber) of \(cap)")
                } else {
                    modeSquareShape(filled: filled)
                }
            }
        }
        .accessibilityElement(children: onSquareTap == nil ? .ignore : .contain)
        .accessibilityLabel(onSquareTap == nil ? "\(min(filledCount, cap)) of \(cap) for this word in the exercise" : "")
    }

    private func modeSquareShape(filled: Bool) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(filled ? Color.green : Color.clear)
            .frame(width: Self.boxSize, height: Self.boxSize)
            .overlay {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
            }
            .contentShape(Rectangle())
    }
}
