//
//  SimpleConstructionModeView.swift
//  FlashCards
//

import SwiftUI
import UIKit

/// Tap tiles in order to build the target word; no scoring or timers.
struct SimpleConstructionModeView: View {
    let word: String
    let segments: [String]

    @Bindable private var appearance = StudyAppearanceSettings.shared
    @Environment(\.dismiss) private var dismiss

    @State private var engine: SimpleConstructionEngine
    @State private var didRunSuccessFlow = false
    @State private var audio = WordAudioPlayer()

    init(word: String, segments: [String]) {
        self.word = word
        self.segments = segments
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
                    engine.reset()
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
            let stem = ConstructionDataSource.normalizedWordKey(word)
            audio.play(stem: stem)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.15))
                dismiss()
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
        case .accepted:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        default:
            break
        }
    }
}

// MARK: - Word list (same module as `SimpleConstructionModeView` so `ExerciseHomeView` always resolves the type)

/// Word list for the Construction exercise: tap a word, then build it from pieces (POC `construction` data).
struct ConstructionPracticeListView: View {
    @Bindable private var appearance = StudyAppearanceSettings.shared

    @State private var exercises: [PhonicsModuleExerciseDTO] = []
    @State private var loadError: String?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let loadError {
                ContentUnavailableView(
                    "Can’t load activities",
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadError)
                )
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if exercises.isEmpty {
                ContentUnavailableView(
                    "No practice words",
                    systemImage: "square.grid.3x3",
                    description: Text("Add entries under `construction` in phonics_modules_poc.json.")
                )
            } else {
                List(exercises) { exercise in
                    NavigationLink {
                        SimpleConstructionModeView(word: exercise.word, segments: exercise.segments)
                            .navigationTitle(exercise.word.capitalized)
                            .navigationBarTitleDisplayMode(.inline)
                            .studyAppearanceToolbar()
                    } label: {
                        Text(exercise.word.capitalized)
                            .font(appearance.bodyFont(size: 17, weight: .medium))
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(appearance.backgroundColor)
        .navigationTitle("Construction")
        .navigationBarTitleDisplayMode(.inline)
        .studyAppearanceToolbar()
        .task { loadExercises() }
    }

    @MainActor
    private func loadExercises() {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let root = try PhonicsModulePOCLoader.load()
            exercises = root.construction
                .sorted { $0.orderIndex < $1.orderIndex }
                .filter { $0.segments.count >= FlashCardsConstants.constructionMinimumSegmentCount }
        } catch {
            loadError = error.localizedDescription
        }
    }
}

#Preview("Construction list") {
    NavigationStack {
        ConstructionPracticeListView()
    }
}

#Preview("Build word") {
    NavigationStack {
        SimpleConstructionModeView(word: "cat", segments: ["c", "a", "t"])
            .studyAppearanceToolbar()
    }
}
