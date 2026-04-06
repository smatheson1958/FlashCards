//
//  AppearanceSettingsSheet.swift
//  FlashCards
//

import SwiftUI

struct AppearanceSettingsSheet: View {
    private enum SettingsTab: String, CaseIterable, Identifiable {
        case font = "Font"
        case colours = "Colours"

        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @Bindable private var appearance = StudyAppearanceSettings.shared
    @State private var selectedTab: SettingsTab = .font

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $selectedTab) {
                    ForEach(SettingsTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .accessibilityLabel("Font or colours")

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        switch selectedTab {
                        case .font:
                            Text("Choose a reading font. Everything here is saved automatically until you change it again.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            settingsBlock(title: "Font") {
                                Text("Lexend and OpenDyslexic are bundled under the SIL Open Font License.")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .fixedSize(horizontal: false, vertical: true)

                                VStack(spacing: 0) {
                                    ForEach(0 ..< 4, id: \.self) { i in
                                        fontOptionRow(index: i)
                                        if i < 3 {
                                            Divider()
                                                .padding(.leading, 36)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(.secondarySystemGroupedBackground))
                                )
                            }

                        case .colours:
                            Text("Pick soft colours for the screen, card, and text. Your choices are saved automatically.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            settingsBlock(title: "Screen background") {
                                pastelPicker(
                                    selection: $appearance.backgroundIndex,
                                    colors: StudyAppearanceSettings.surfaceColors,
                                    names: StudyAppearanceSettings.surfaceNames
                                )
                            }

                            settingsBlock(title: "Surround (hints & outline)") {
                                pastelPicker(
                                    selection: $appearance.surroundIndex,
                                    colors: StudyAppearanceSettings.surfaceColors,
                                    names: StudyAppearanceSettings.surfaceNames
                                )
                            }

                            settingsBlock(title: "Card") {
                                pastelPicker(
                                    selection: $appearance.cardIndex,
                                    colors: StudyAppearanceSettings.surfaceColors,
                                    names: StudyAppearanceSettings.surfaceNames
                                )
                            }

                            settingsBlock(title: "Letters & words") {
                                pastelPicker(
                                    selection: $appearance.textIndex,
                                    colors: StudyAppearanceSettings.textColors,
                                    names: StudyAppearanceSettings.textNames
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Look & text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func settingsBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pastelPicker(selection: Binding<Int>, colors: [Color], names: [String]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 12)], spacing: 12) {
            ForEach(0 ..< 4, id: \.self) { i in
                Button {
                    selection.wrappedValue = i
                } label: {
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(colors[i])
                            .frame(height: 44)
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(selection.wrappedValue == i ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: selection.wrappedValue == i ? 2.5 : 1)
                            }
                        Text(names[i])
                            .font(.caption2)
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(names[i]) colour")
                .accessibilityAddTraits(selection.wrappedValue == i ? [.isSelected] : [])
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func fontOptionRow(index i: Int) -> some View {
        Button {
            appearance.fontIndex = i
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: appearance.fontIndex == i ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(appearance.fontIndex == i ? Color.accentColor : Color.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text(StudyAppearanceSettings.fontTitles[i])
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(StudyAppearanceSettings.fontFootnotes[i])
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(StudyAppearanceSettings.fontPreviewSample)
                        .font(StudyAppearanceSettings.previewFont(forOptionIndex: i, size: 20, weight: .regular))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(StudyAppearanceSettings.fontTitles[i]) font")
        .accessibilityAddTraits(appearance.fontIndex == i ? [.isSelected] : [])
    }
}

struct StudyAppearanceToolbarModifier: ViewModifier {
    @State private var showAppearanceSheet = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAppearanceSheet = true
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Colours and font")
                }
            }
            .sheet(isPresented: $showAppearanceSheet) {
                AppearanceSettingsSheet()
            }
    }
}

extension View {
    func studyAppearanceToolbar() -> some View {
        modifier(StudyAppearanceToolbarModifier())
    }
}
