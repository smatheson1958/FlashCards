//
//  SimpleConstructionModeView.swift
//  FlashCards
//

import SwiftData
import SwiftUI
import UIKit

/// Tap tiles in order to build the target word; optional hooks for per-word mode progress and reminder resets.
struct SimpleConstructionModeView: View {
    let word: String
    let segments: [String]
    /// Matches `ConstructionIndexG1ItemDTO.id` / Sound Card `orderIndex` when opened from phonics; `nil` uses flat `WordsAudio/<stem>.wav` only.
    var soundOrderIndex: Int?
    var isReminderSession: Bool
    var dismissAfterSuccess: Bool
    var onSuccessfulCompletion: (() -> Void)?
    var onReminderWrongTap: (() -> Void)?

    @Bindable private var appearance = StudyAppearanceSettings.shared
    @Environment(\.dismiss) private var dismiss

    @State private var engine: SimpleConstructionEngine
    @State private var didRunSuccessFlow = false
    @State private var audio = WordAudioPlayer()

    init(
        word: String,
        segments: [String],
        soundOrderIndex: Int? = nil,
        isReminderSession: Bool = false,
        dismissAfterSuccess: Bool = true,
        onSuccessfulCompletion: (() -> Void)? = nil,
        onReminderWrongTap: (() -> Void)? = nil
    ) {
        self.word = word
        self.segments = segments
        self.soundOrderIndex = soundOrderIndex
        self.isReminderSession = isReminderSession
        self.dismissAfterSuccess = dismissAfterSuccess
        self.onSuccessfulCompletion = onSuccessfulCompletion
        self.onReminderWrongTap = onReminderWrongTap
        let count = ConstructionTilePoolBuilder.distractorCount(forSegmentCount: segments.count)
        let distractors = ConstructionTilePoolBuilder.distractorLabels(forTargetSegments: segments, count: count)
        _engine = State(
            initialValue: SimpleConstructionEngine(targetSegments: segments, distractorLabels: distractors)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text(word.capitalized)
                    .font(appearance.titleFont(size: 34, weight: .semibold))
                    .foregroundStyle(appearance.primaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)

                Text("Tap the pieces in order.")
                    .font(appearance.bodyFont(size: 15))
                    .foregroundStyle(appearance.primaryTextColor.opacity(0.75))

                slotsRow
                    .accessibilityElement(children: .combine)

                Text("Pieces")
                    .font(appearance.bodyFont(size: 13, weight: .semibold))
                    .foregroundStyle(appearance.primaryTextColor.opacity(0.65))

                tileGrid

                Button("Start over") {
                    var next = engine
                    next.reset()
                    engine = next
                    didRunSuccessFlow = false
                    audio.stop()
                }
                .font(appearance.bodyFont(size: 16, weight: .medium))
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .accessibilityHint("Clears slots and shuffles pieces again.")
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(appearance.backgroundColor)
        .animation(.easeInOut(duration: 0.18), value: engine.progress)
        .onChange(of: engine.isComplete) { _, complete in
            guard complete, !didRunSuccessFlow else { return }
            didRunSuccessFlow = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onSuccessfulCompletion?()
            let stem = ConstructionDataSource.normalizedWordKey(word)
            audio.play(stem: stem, soundOrderIndex: soundOrderIndex)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.15))
                if dismissAfterSuccess {
                    dismiss()
                } else {
                    var nextEngine = engine
                    nextEngine.reset()
                    engine = nextEngine
                    didRunSuccessFlow = false
                }
            }
        }
    }

    private var slotsRow: some View {
        HStack(spacing: 10) {
            ForEach(0 ..< engine.slotCount, id: \.self) { index in
                slotCell(at: index)
            }
        }
    }

    private func slotCell(at index: Int) -> some View {
        let label = engine.labelAtSlot(index)
        return Text(label ?? "—")
            .font(appearance.titleFont(size: 22, weight: .semibold))
            .foregroundStyle(
                label == nil
                    ? appearance.primaryTextColor.opacity(0.28)
                    : appearance.primaryTextColor
            )
            .frame(minWidth: 48, minHeight: 56)
            .frame(maxWidth: .infinity)
            .background(appearance.cardFillColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(appearance.surroundColor.opacity(0.4), lineWidth: 1)
            )
            .accessibilityLabel(label == nil ? "Empty slot \(index + 1)" : "Slot \(index + 1), \(label!)")
    }

    private var tileGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 72), spacing: 12, alignment: .center)],
            spacing: 12
        ) {
            ForEach(engine.pool) { tile in
                Button {
                    handleTileTap(tile)
                } label: {
                    Text(tile.label)
                        .font(appearance.titleFont(size: 20, weight: .medium))
                        .foregroundStyle(appearance.primaryTextColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(appearance.cardFillColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(appearance.surroundColor.opacity(0.35), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Piece \(tile.label)")
                .accessibilityHint("Adds this piece if it is next in the word.")
            }
        }
    }

    private func handleTileTap(_ tile: ConstructionPoolTile) {
        var next = engine
        let result = next.handleTap(tileID: tile.id)
        engine = next
        switch result {
        case .wrong:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if isReminderSession {
                onReminderWrongTap?()
                var cleared = engine
                cleared.reset()
                engine = cleared
                didRunSuccessFlow = false
            }
        case .accepted:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        default:
            break
        }
    }
}

// MARK: - Word list

/// Construction practice: working sounds from Sound Cards + `construction_index_g1_foundation.json`.
struct ConstructionPracticeListView: View {
    var body: some View {
        PhonicsModeSoundListView(mode: .construction)
    }
}

#Preview("Construction list") {
    let schema = Schema([CardProgress.self, ModeWordProgress.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: config)
    return NavigationStack {
        ConstructionPracticeListView()
    }
    .modelContainer(container)
}

#Preview("Build word") {
    NavigationStack {
        SimpleConstructionModeView(word: "cat", segments: ["c", "a", "t"])
            .studyAppearanceToolbar()
    }
}
