//
//  ExerciseHomeView.swift
//  FlashCards
//

import SwiftData
import SwiftUI

struct ExerciseHomeView: View {
    @Bindable var session: StudySessionStore
    var isLibraryPreparing: Bool

    @Bindable private var appearance = StudyAppearanceSettings.shared

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Choose an exercise")
                    .font(appearance.bodyFont(size: 15))
                    .foregroundStyle(appearance.primaryTextColor)
                    .padding(.horizontal, 4)

                LazyVGrid(columns: columns, spacing: 16) {
                    NavigationLink {
                        FlashCardStudyView(session: session, isLibraryPreparing: isLibraryPreparing)
                            .navigationTitle("Sounds")
                            .navigationBarTitleDisplayMode(.inline)
                            .studyAppearanceToolbar()
                    } label: {
                        exerciseTile(
                            title: "Sounds",
                            subtitle: "Sound and word cards",
                            systemImage: "waveform"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        ExerciseComingSoonView(
                            title: "Spelling",
                            message: "Spelling practice will be added here — structured spelling exercises separate from the word list."
                        )
                        .navigationTitle("Spelling")
                        .navigationBarTitleDisplayMode(.inline)
                        .studyAppearanceToolbar()
                    } label: {
                        exerciseTile(
                            title: "Spelling",
                            subtitle: "Coming soon",
                            systemImage: "character.cursor.ibeam"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        SegmentationPracticeListView()
                    } label: {
                        exerciseTile(
                            title: "Segmentation",
                            subtitle: "Break words apart",
                            systemImage: "rectangle.split.3x1"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        ConstructionPracticeListView()
                    } label: {
                        exerciseTile(
                            title: "Construction",
                            subtitle: "Build words",
                            systemImage: "square.grid.3x3.fill"
                        )
                    }
                    .buttonStyle(.plain)
                }

//                Text("Memory words")
//                    .font(appearance.bodyFont(size: 15))
//                    .foregroundStyle(appearance.primaryTextColor)
//                    .padding(.horizontal, 4)
//                    .padding(.top, 8)

                LazyVGrid(columns: columns, spacing: 16) {
                    NavigationLink {
                        WordStudyView(isLibraryPreparing: isLibraryPreparing)
                            .navigationTitle("Words")
                            .navigationBarTitleDisplayMode(.inline)
                            .studyAppearanceToolbar()
                    } label: {
                        exerciseTile(
                            title: "Words",
                            subtitle: "Listen and practice each word",
                            systemImage: "text.bubble"
                        )
                    }
                    .buttonStyle(.plain)
                    .gridCellColumns(2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .padding(.bottom, 24)
        }
        .background(appearance.backgroundColor)
        .navigationTitle("Exercises")
        .navigationBarTitleDisplayMode(.large)
        .studyAppearanceToolbar()
    }

    private func exerciseTile(title: String, subtitle: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .medium))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(appearance.primaryTextColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(title)
                .font(appearance.titleFont(size: 20, weight: .semibold))
                .foregroundStyle(appearance.primaryTextColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(subtitle)
                .font(appearance.bodyFont(size: 14, weight: .medium))
                // Stronger than title tint so small type stays legible on pastel card fills.
                .foregroundStyle(Color(red: 0.08, green: 0.09, blue: 0.12))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(appearance.cardFillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(appearance.surroundColor.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: appearance.surroundColor.opacity(0.2), radius: 10, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct ExerciseComingSoonView: View {
    let title: String
    let message: String

    @Bindable private var appearance = StudyAppearanceSettings.shared

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "hammer.fill")
        } description: {
            Text(message)
                .font(appearance.bodyFont(size: 15))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(appearance.backgroundColor)
    }
}
