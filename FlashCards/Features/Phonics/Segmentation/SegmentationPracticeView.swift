//
//  SegmentationPracticeView.swift
//  FlashCards
//

import SwiftUI
import UIKit

/// Hear segment sounds and the whole word; uses bundled `segmentation` entries in phonics_modules_poc.json.
struct SegmentationModeView: View {
    let word: String
    let segments: [String]

    @Bindable private var appearance = StudyAppearanceSettings.shared

    @State private var segmentPlayer = SegmentationSoundPlayer()
    @State private var wordPlayer = WordAudioPlayer()

    var body: some View {
        VStack(spacing: 36) {
            Spacer(minLength: 0)

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                segmentPlayer.stop()
                let stem = ConstructionDataSource.normalizedWordKey(word)
                wordPlayer.play(stem: stem)
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

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(appearance.backgroundColor)
    }
}

/// Word list for Segmentation: tap a word to explore its segments (POC `segmentation` data).
struct SegmentationPracticeListView: View {
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
                    systemImage: "rectangle.split.3x1",
                    description: Text("Add entries under `segmentation` in phonics_modules_poc.json.")
                )
            } else {
                List(exercises) { exercise in
                    NavigationLink {
                        SegmentationModeView(word: exercise.word, segments: exercise.segments)
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
        .navigationTitle("Segmentation")
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
            exercises = root.segmentation
                .sorted { $0.orderIndex < $1.orderIndex }
                .filter { !$0.segments.isEmpty }
        } catch {
            loadError = error.localizedDescription
        }
    }
}

#Preview("Segmentation list") {
    NavigationStack {
        SegmentationPracticeListView()
    }
}

#Preview("Segmentation word") {
    NavigationStack {
        SegmentationModeView(word: "cat", segments: ["c", "a", "t"])
            .studyAppearanceToolbar()
    }
}
