//
//  PhonicsSoundWordDrillView.swift
//  FlashCards
//
//  Chains up to `FlashCardsConstants.phonicsWordsPerSoundDrillSession` words for one sound, then dismisses back to the working-sounds list.
//

import SwiftData
import SwiftUI

struct PhonicsSoundWordDrillView: View {
    let mode: PhonicsModeExerciseKind
    let card: CardProgress
    let wordQueue: [String]

    @Environment(\.modelContext) private var modelContext
    @Bindable private var appearance = StudyAppearanceSettings.shared

    @State private var slotIndex = 0
    @State private var advanceSlotTask: Task<Void, Never>?
    /// Covers practice UI during the post-success delay so the next screen cannot flash before navigation pops.
    @State private var veilPracticeDuringPop = false

    private var activeWord: String {
        guard wordQueue.indices.contains(slotIndex) else {
            return wordQueue.last ?? ""
        }
        return wordQueue[slotIndex]
    }

    private var isFinalWordInQueue: Bool {
        slotIndex >= wordQueue.count - 1
    }

    var body: some View {
        VStack(spacing: 0) {
            if wordQueue.count > 1 && !veilPracticeDuringPop {
                PhonicsMultiStepDotProgress(activeIndex: slotIndex, stepCount: wordQueue.count)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(appearance.backgroundColor)
            }

            ZStack {
                Group {
                    switch mode {
                    case .construction:
                        SimpleConstructionModeView(
                            word: activeWord,
                            segments: segments(for: activeWord),
                            soundOrderIndex: card.orderIndex,
                            isReminderSession: false,
                            dismissAfterSuccess: isFinalWordInQueue,
                            suppressPostSuccessReset: !isFinalWordInQueue,
                            onSuccessfulCompletion: {
                                let completed = activeWord
                                ModeWordProgressService.recordSuccessfulAttempt(
                                    soundOrderIndex: card.orderIndex,
                                    mode: .construction,
                                    word: completed,
                                    context: modelContext
                                )
                                if slotIndex < wordQueue.count - 1 {
                                    scheduleAdvanceSlotConstructionDelay()
                                } else {
                                    cancelAdvanceSlotTask()
                                    veilPracticeDuringPop = true
                                }
                            },
                            onReminderWrongTap: nil
                        )
                    case .segmentation:
                        SegmentationModeView(
                            word: activeWord,
                            segments: segments(for: activeWord),
                            soundOrderIndex: card.orderIndex,
                            isReminderSession: false,
                            dismissAfterRecordingSuccess: isFinalWordInQueue,
                            showPracticeMissButton: false,
                            onSuccessfulPracticeRecorded: {
                                let completed = activeWord
                                ModeWordProgressService.recordSuccessfulAttempt(
                                    soundOrderIndex: card.orderIndex,
                                    mode: .segmentation,
                                    word: completed,
                                    context: modelContext
                                )
                                if slotIndex < wordQueue.count - 1 {
                                    scheduleAdvanceSlotSegmentationDelay()
                                } else {
                                    cancelAdvanceSlotTask()
                                    veilPracticeDuringPop = true
                                }
                            },
                            onPracticeMissed: nil,
                            onReminderMissed: nil
                        )
                    }
                }
                .id("\(slotIndex)-\(activeWord)")

                if veilPracticeDuringPop {
                    Rectangle()
                        .fill(appearance.backgroundColor)
                        .allowsHitTesting(true)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(wordQueue.count > 1 ? "" : activeWord.capitalized)
        .navigationBarTitleDisplayMode(.inline)
        .studyAppearanceToolbar()
        .animation(veilPracticeDuringPop ? nil : .easeInOut(duration: 0.22), value: slotIndex)
        .onDisappear {
            cancelAdvanceSlotTask()
        }
    }

    private func cancelAdvanceSlotTask() {
        advanceSlotTask?.cancel()
        advanceSlotTask = nil
    }

    private func scheduleAdvanceSlotConstructionDelay() {
        cancelAdvanceSlotTask()
        advanceSlotTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.15))
            guard !Task.isCancelled else { return }
            slotIndex += 1
        }
    }

    private func scheduleAdvanceSlotSegmentationDelay() {
        cancelAdvanceSlotTask()
        advanceSlotTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            slotIndex += 1
        }
    }

    private func segments(for word: String) -> [String] {
        if mode == .segmentation {
            return SegmentationDataSource.resolvedSegments(forWord: word, soundOrderIndex: card.orderIndex)
        }
        return ConstructionIndexG1Loader.graphemeUnits(forSoundOrderIndex: card.orderIndex, word: word)
            ?? ConstructionDataSource.segments(forWord: word)
    }
}
