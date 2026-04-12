//
//  PhonicsModeWordSessionView.swift
//  FlashCards
//

import SwiftData
import SwiftUI

/// Wraps Construction or Segmentation practice and records `ModeWordProgress` / reminder resets.
struct PhonicsModeWordSessionView: View {
    let mode: PhonicsModeExerciseKind
    let soundOrderIndex: Int
    let word: String
    let segments: [String]
    let isReminder: Bool

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            switch mode {
            case .construction:
                SimpleConstructionModeView(
                    word: word,
                    segments: segments,
                    isReminderSession: isReminder,
                    dismissAfterSuccess: true,
                    onSuccessfulCompletion: {
                        ModeWordProgressService.recordSuccessfulAttempt(
                            soundOrderIndex: soundOrderIndex,
                            mode: .construction,
                            word: word,
                            context: modelContext
                        )
                    },
                    onReminderWrongTap: {
                        ModeWordProgressService.resetFromReminderWrong(
                            soundOrderIndex: soundOrderIndex,
                            mode: .construction,
                            word: word,
                            context: modelContext
                        )
                    }
                )
            case .segmentation:
                SegmentationModeView(
                    word: word,
                    segments: segments,
                    isReminderSession: isReminder,
                    dismissAfterRecordingSuccess: true,
                    onSuccessfulPracticeRecorded: {
                        ModeWordProgressService.recordSuccessfulAttempt(
                            soundOrderIndex: soundOrderIndex,
                            mode: .segmentation,
                            word: word,
                            context: modelContext
                        )
                    },
                    onReminderMissed: {
                        ModeWordProgressService.resetFromReminderWrong(
                            soundOrderIndex: soundOrderIndex,
                            mode: .segmentation,
                            word: word,
                            context: modelContext
                        )
                    }
                )
            }
        }
        .navigationTitle(word.capitalized)
        .navigationBarTitleDisplayMode(.inline)
        .studyAppearanceToolbar()
    }
}
