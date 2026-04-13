//
//  SegmentationJourneySessionView.swift
//  FlashCards
//
//  JSON-driven visit pairs across unlocked sounds only (Section 8). Global sound order comes from `CardProgress.orderIndex`.
//

import SwiftData
import SwiftUI

struct SegmentationJourneySessionView: View {
    @Bindable private var appearance = StudyAppearanceSettings.shared
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<CardProgress> { card in
            card.deckStateRaw != "notIntroduced" && card.masteryCorrectCount >= 3
        },
        sort: \CardProgress.orderIndex
    )
    private var qualifyingSoundCards: [CardProgress]

    @State private var prependQueue: [SegmentationJourneyStep] = []
    @State private var sessionSoundAttendance: Set<Int> = []
    @State private var activeStep: SegmentationJourneyStep?
    /// Bumps when the learner records a miss so the same `step.id` still recreates the practice view.
    @State private var journeyViewIdentity: Int = 0

    private var workingSounds: [CardProgress] {
        let cap = FlashCardsConstants.currentDeckTargetCount
        let slice = Array(qualifyingSoundCards.prefix(cap))
        return slice.filter { card in
            let snap = SoundCardProgressSnapshot(card: card)
            return LearningProgressionEngine.isSegmentationUnlocked(snap)
        }
    }

    var body: some View {
        Group {
            if let step = activeStep {
                SegmentationJourneyWordSessionView(
                    step: step,
                    prependQueue: $prependQueue,
                    sessionSoundAttendance: $sessionSoundAttendance,
                    onSuccessFinished: { advanceAfterSuccess(step) },
                    onMissFinished: {
                        journeyViewIdentity += 1
                        refillActiveStepIfNeeded()
                    }
                )
                .id("\(step.id)|\(journeyViewIdentity)")
            } else if workingSounds.isEmpty {
                ContentUnavailableView(
                    "No unlocked sounds",
                    systemImage: "lock.open",
                    description: Text("Introduce sounds in the teaching deck and get enough Sound Card practice to unlock segmentation.")
                )
            } else {
                ContentUnavailableView(
                    "Journey up to date",
                    systemImage: "checkmark.circle",
                    description: Text("Every visit pair is complete for the working sounds, or words are missing segmentation data.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(appearance.backgroundColor)
        .navigationTitle("Segmentation journey")
        .navigationBarTitleDisplayMode(.inline)
        .studyAppearanceToolbar()
        .onAppear {
            refillActiveStepIfNeeded()
        }
        .onChange(of: qualifyingSoundCards.count) { _, _ in
            refillActiveStepIfNeeded()
        }
    }

    private func advanceAfterSuccess(_ completed: SegmentationJourneyStep) {
        if prependQueue.first?.id == completed.id {
            prependQueue.removeFirst()
        }
        journeyViewIdentity += 1
        refillActiveStepIfNeeded()
    }

    private func refillActiveStepIfNeeded() {
        if let head = prependQueue.first {
            activeStep = head
            return
        }
        activeStep = SegmentationModuleProgressService.nextJourneyStep(workingSounds: workingSounds, context: modelContext)
    }
}

// MARK: - Single word session (journey)

private struct SegmentationJourneyWordSessionView: View {
    let step: SegmentationJourneyStep
    @Binding var prependQueue: [SegmentationJourneyStep]
    @Binding var sessionSoundAttendance: Set<Int>
    var onSuccessFinished: () -> Void
    var onMissFinished: () -> Void

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        SegmentationModeView(
            word: step.word,
            segments: step.segments,
            soundOrderIndex: step.soundOrderIndex,
            isReminderSession: false,
            dismissAfterRecordingSuccess: false,
            showPracticeMissButton: true,
            onSuccessfulPracticeRecorded: {
                ModeWordProgressService.recordSuccessfulAttempt(
                    soundOrderIndex: step.soundOrderIndex,
                    mode: .segmentation,
                    word: step.word,
                    context: modelContext
                )
                SegmentationModuleProgressService.recordJourneyWordSuccess(
                    soundOrderIndex: step.soundOrderIndex,
                    word: step.word,
                    visitIndex: step.visitIndex,
                    context: modelContext
                )
                try? modelContext.save()
                onSuccessFinished()
            },
            onPracticeMissed: {
                let directive = SegmentationModuleProgressService.recordJourneyWordError(
                    soundOrderIndex: step.soundOrderIndex,
                    word: step.word,
                    visitIndex: step.visitIndex,
                    context: modelContext
                )
                switch directive {
                case let .repeatCurrentPairImmediately(word0, word1, segments0, segments1):
                    let extra = SegmentationModuleProgressService.journeyStepsForPair(
                        soundOrderIndex: step.soundOrderIndex,
                        visitIndex: step.visitIndex,
                        word0: word0,
                        word1: word1,
                        segments0: segments0,
                        segments1: segments1
                    )
                    prependQueue.insert(contentsOf: extra, at: 0)
                case .reopenPreviousVisitPair:
                    // Module row already moved `activeVisitIndexForPair` back; `nextJourneyStep` will surface the previous pair.
                    break
                case .none:
                    break
                }
                try? modelContext.save()
                onMissFinished()
            },
            onReminderMissed: nil
        )
        .onAppear {
            SegmentationModuleProgressService.recordWordPresented(
                soundOrderIndex: step.soundOrderIndex,
                word: step.word,
                visitIndex: step.visitIndex,
                sessionRecordedSounds: &sessionSoundAttendance,
                context: modelContext
            )
            try? modelContext.save()
        }
        .navigationTitle(step.word.capitalized)
        .navigationBarTitleDisplayMode(.inline)
    }
}
