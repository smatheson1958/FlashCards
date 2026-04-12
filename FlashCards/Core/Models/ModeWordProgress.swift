//
//  ModeWordProgress.swift
//  FlashCards
//

import Foundation
import SwiftData

@Model
final class ModeWordProgress {
    /// Stable key: `"\(soundOrderIndex)|\(modeRaw)|\(wordKey)"` with normalized `wordKey`.
    @Attribute(.unique) var progressID: String
    var soundOrderIndex: Int
    var modeRaw: String
    /// Lowercased trimmed spelling key (matches `ConstructionDataSource.normalizedWordKey`).
    var wordKey: String
    /// Correct completions toward mastery for this mode (0…`FlashCardsConstants.modeExerciseWordMasteryCount`).
    var correctCountTowardMastery: Int

    init(progressID: String, soundOrderIndex: Int, kind: PhonicsModeExerciseKind, wordKey: String, correctCountTowardMastery: Int = 0) {
        self.progressID = progressID
        self.soundOrderIndex = soundOrderIndex
        self.modeRaw = kind.rawValue
        self.wordKey = wordKey
        self.correctCountTowardMastery = correctCountTowardMastery
    }

    var mode: PhonicsModeExerciseKind {
        get { PhonicsModeExerciseKind(rawValue: modeRaw) ?? .construction }
        set { modeRaw = newValue.rawValue }
    }
}
