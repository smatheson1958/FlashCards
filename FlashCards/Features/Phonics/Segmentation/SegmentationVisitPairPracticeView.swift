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

    @Bindable private var appearance = StudyAppearanceSettings.shared
    @Environment(\.modelContext) private var modelContext

    @State private var activeSlot: Int = 0

    var body: some View {
        Group {
            if activeSlot == 0 {
                pairWordView(
                    word: word0,
                    segments: segments0,
                    dismissAfterSuccess: false,
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
                    viewIdSuffix: "b",
                    onSuccess: {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(appearance.backgroundColor)
        .navigationTitle(
            (isReviewSession ? "Review · " : "")
                + (activeSlot == 0 ? "1 of 2 · \(word0.capitalized)" : "2 of 2 · \(word1.capitalized)")
        )
        .navigationBarTitleDisplayMode(.inline)
        .studyAppearanceToolbar()
    }

    @ViewBuilder
    private func pairWordView(
        word: String,
        segments: [String],
        dismissAfterSuccess: Bool,
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
            onReminderMissed: nil
        )
        .id("visitPair-\(soundOrderIndex)-\(visitIndex)-\(viewIdSuffix)-\(word)")
    }
}
