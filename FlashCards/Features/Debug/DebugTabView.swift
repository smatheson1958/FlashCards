//
//  DebugTabView.swift
//  FlashCards
//
//  DEBUG-only tab: development tools and future rule toggles.
//

#if DEBUG
import SwiftData
import SwiftUI

struct DebugTabView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage(FlashCardsConstants.userDefaultsKeyDebugShowSuccessfulReviewPriority)
    private var showSuccessfulReviewPriority = false

    @State private var showRebuildDeckConfirm = false
    @State private var rebuildDeckErrorMessage: String?
    @State private var scoreAdjustErrorMessage: String?
    @State private var lastPhonicsRebuildCompletedAt: Date?
    @State private var lastTeachingDeckScoresCompletedAt: Date?

    private var almostMasteredCount: Int {
        max(0, FlashCardsConstants.masteryThreshold - 1)
    }

    var body: some View {
        List {
            Section {
                Text("Development-only controls. Not included in Release builds.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }

            Section {
                VStack(alignment: .leading, spacing: 14) {
                    Text(
                        """
                        Deletes all Sound Card rows (`CardProgress`), Construction/Segmentation per-word rows (`ModeWordProgress`), segmentation journey module rows (`SegmentationSoundModuleProgress`), and segmentation audit events (`SegmentationProgressEvent`), then re-imports phonics from the bundled seed.

                        Also clears in-memory caches: sound-units curriculum (`LearningProgressionEngine`), G1 construction index JSON, POC construction segment map (`ConstructionDataSource`), segmentation journey seed (`SegmentationJourneyLoader`), and segmentation POC map (`SegmentationDataSource`).

                        Word cards and appearance settings are unchanged.
                        """
                    )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        showRebuildDeckConfirm = true
                    } label: {
                        Label("Run full rebuild", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)

                    if let at = lastPhonicsRebuildCompletedAt {
                        completionBanner(text: "Rebuild finished", completedAt: at)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Phonics data")
            }

            Section {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Sets `masteryCorrectCount` to \(almostMasteredCount) on every card in the teaching deck so the next correct swipe can graduate a card (if nothing else blocks).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        setCurrentDeckMasteryToAlmostMastered()
                    } label: {
                        Label(
                            "Apply \(almostMasteredCount) / \(FlashCardsConstants.masteryThreshold) scores",
                            systemImage: "4.circle"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    if let at = lastTeachingDeckScoresCompletedAt {
                        completionBanner(text: "Scores updated", completedAt: at)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Teaching deck")
            }

            Section {
                Toggle("Show Priority", isOn: $showSuccessfulReviewPriority)
                Text("When on, the Current deck list shows each mastered card’s review-priority weight above the mastery indicators (used when picking review cards in Sounds).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Deck list")
            }
        }
        .navigationTitle("Debug")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog(
            "Replace the entire phonics deck with a fresh import from seed? All Sound Card progress is deleted.",
            isPresented: $showRebuildDeckConfirm,
            titleVisibility: .visible
        ) {
            Button("Rebuild from seed", role: .destructive) {
                rebuildPhonicsDeckFromSeed()
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Couldn’t rebuild deck", isPresented: Binding(
            get: { rebuildDeckErrorMessage != nil },
            set: { if !$0 { rebuildDeckErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { rebuildDeckErrorMessage = nil }
        } message: {
            Text(rebuildDeckErrorMessage ?? "")
        }
        .alert("Couldn’t adjust scores", isPresented: Binding(
            get: { scoreAdjustErrorMessage != nil },
            set: { if !$0 { scoreAdjustErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { scoreAdjustErrorMessage = nil }
        } message: {
            Text(scoreAdjustErrorMessage ?? "")
        }
    }

    private func completionBanner(text: String, completedAt: Date) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(.subheadline.weight(.semibold))
                Text(completedAt, format: .dateTime.hour().minute().second())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.green.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(text) at \(completedAt.formatted(date: .omitted, time: .standard))")
    }

    private func setCurrentDeckMasteryToAlmostMastered() {
        let cards = DeckManager.cards(in: .currentDeck, context: modelContext)
        let n = almostMasteredCount
        for card in cards {
            card.masteryCorrectCount = n
        }
        do {
            try modelContext.save()
            lastTeachingDeckScoresCompletedAt = Date()
        } catch {
            scoreAdjustErrorMessage = error.localizedDescription
        }
    }

    private func rebuildPhonicsDeckFromSeed() {
        do {
            try SeedImporter.rebuildPhonicsDeckFromSeed(context: modelContext)
            NotificationCenter.default.post(name: .phonicsDeckDidRebuildFromSeed, object: nil)
            lastPhonicsRebuildCompletedAt = Date()
        } catch {
            rebuildDeckErrorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        DebugTabView()
    }
    .modelContainer(for: CardProgress.self, inMemory: true)
}
#endif
