//
//  SegmentationVisitPairPracticeView.swift
//  FlashCards
//
//  Presents both words of one visit pair back-to-back (hub “Words” list and visit-pair model).
//

import SwiftData
import SwiftUI

struct SegmentationVisitPairPracticeView: View {
    let soundOrderIndex: Int
    let visitIndex: Int
    let word0: String
    let word1: String
    let segments0: [String]
    let segments1: [String]
    /// When false (e.g. optional review after the hub is complete), successes are not written to `ModeWordProgress`.
    var recordsProgress: Bool = true
    /// Prefixes navigation titles with “Review ·” when true.
    var isReviewSession: Bool = false
    /// When non-nil, finishing the second word calls this instead of dismissing (hub mini lesson chaining).
    var onPairFullyCompleteInsteadOfDismiss: (() -> Void)? = nil

    @Bindable private var appearance = StudyAppearanceSettings.shared
    @Environment(\.modelContext) private var modelContext

    @State private var activeSlot: Int = 0
    @State private var veilPracticeDuringPop = false

    var body: some View {
        VStack(spacing: 0) {
            if !veilPracticeDuringPop {
                PhonicsMultiStepDotProgress(activeIndex: activeSlot, stepCount: 2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(appearance.backgroundColor)
            }

            ZStack {
                Group {
                    if activeSlot == 0 {
                        pairWordView(
                            word: word0,
                            segments: segments0,
                            dismissAfterSuccess: false,
                            customDismissAfterSuccess: nil,
                            viewIdSuffix: "a",
                            onSuccess: {
                                if recordsProgress {
                                    ModeWordProgressService.recordSuccessfulAttempt(
                                        soundOrderIndex: soundOrderIndex,
                                        mode: .segmentation,
                                        word: word0,
                                        context: modelContext
                                    )
                                    try? modelContext.save()
                                }
                                activeSlot = 1
                            }
                        )
                    } else {
                        pairWordView(
                            word: word1,
                            segments: segments1,
                            dismissAfterSuccess: true,
                            customDismissAfterSuccess: onPairFullyCompleteInsteadOfDismiss,
                            viewIdSuffix: "b",
                            onSuccess: {
                                veilPracticeDuringPop = true
                                if recordsProgress {
                                    ModeWordProgressService.recordSuccessfulAttempt(
                                        soundOrderIndex: soundOrderIndex,
                                        mode: .segmentation,
                                        word: word1,
                                        context: modelContext
                                    )
                                    try? modelContext.save()
                                }
                            }
                        )
                    }
                }

                if veilPracticeDuringPop {
                    Rectangle()
                        .fill(appearance.backgroundColor)
                        .allowsHitTesting(true)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(appearance.backgroundColor)
        .navigationTitle(isReviewSession ? "Review" : "")
        .navigationBarTitleDisplayMode(.inline)
        .studyAppearanceToolbar()
        .animation(veilPracticeDuringPop ? nil : .easeInOut(duration: 0.22), value: activeSlot)
    }

    @ViewBuilder
    private func pairWordView(
        word: String,
        segments: [String],
        dismissAfterSuccess: Bool,
        customDismissAfterSuccess: (() -> Void)?,
        viewIdSuffix: String,
        onSuccess: @escaping () -> Void
    ) -> some View {
        SegmentationModeView(
            word: word,
            segments: segments,
            soundOrderIndex: soundOrderIndex,
            isReminderSession: false,
            dismissAfterRecordingSuccess: dismissAfterSuccess,
            showPracticeMissButton: false,
            onSuccessfulPracticeRecorded: onSuccess,
            onPracticeMissed: nil,
            onReminderMissed: nil,
            onDismissAfterSuccess: customDismissAfterSuccess
        )
        .id("visitPair-\(soundOrderIndex)-\(visitIndex)-\(viewIdSuffix)-\(word)")
    }
}
