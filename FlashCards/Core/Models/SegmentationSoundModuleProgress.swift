//
//  SegmentationSoundModuleProgress.swift
//  FlashCards
//
//  Module-local segmentation ladder: visit pairs passed (mask), active pair slots, and “segmentation secure” signals.
//  Does not control global sound ordering or global mastery.
//

import Foundation
import SwiftData

@Model
final class SegmentationSoundModuleProgress {
    /// Matches `CardProgress.orderIndex` / curriculum `orderIndex`.
    @Attribute(.unique) var soundOrderIndex: Int
    /// Bits 0…4 correspond to visit pairs 1…5 completed for this sound.
    var visitsPassedMask: Int
    var pairSlot0Passed: Bool
    var pairSlot1Passed: Bool
    /// Visit index (1…5) for the pair currently being completed (`pairSlot*` refer to this visit).
    var activeVisitIndexForPair: Int
    var errorsOnCurrentPairCycle: Int
    /// Third error on the same pair window (Section 8.3); scheduling hint for future sessions.
    var isFragile: Bool
    /// Module-local “secure” (Section 8.4); not global mastery.
    var isSegmentationSecure: Bool
    /// Comma-separated normalized word keys that have recorded at least one journey success.
    var distinctSuccessWordKeysCSV: String
    var lifetimeJourneyCorrectCount: Int
    var lifetimeJourneyIncorrectCount: Int
    /// Trailing history: `1` = success, `0` = miss/error; capped in service (newest last).
    var recentOutcomeChars: String
    var lastActivityAt: Date?

    init(soundOrderIndex: Int) {
        self.soundOrderIndex = soundOrderIndex
        self.visitsPassedMask = 0
        self.pairSlot0Passed = false
        self.pairSlot1Passed = false
        self.activeVisitIndexForPair = 1
        self.errorsOnCurrentPairCycle = 0
        self.isFragile = false
        self.isSegmentationSecure = false
        self.distinctSuccessWordKeysCSV = ""
        self.lifetimeJourneyCorrectCount = 0
        self.lifetimeJourneyIncorrectCount = 0
        self.recentOutcomeChars = ""
        self.lastActivityAt = nil
    }
}
