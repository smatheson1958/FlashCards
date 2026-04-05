//
//  WordCard.swift
//  FlashCards
//

import Foundation
import SwiftData

@Model
final class WordCard {
    @Attribute(.unique) var wordID: String
    var orderIndex: Int
    /// Display text (capitalized in UI as needed).
    var word: String
    /// Base name for `\(playbackStem).wav` — from seed; can differ from `word` when filenames don’t match spelling.
    var audioStem: String

    init(wordID: String, orderIndex: Int, word: String, audioStem: String) {
        self.wordID = wordID
        self.orderIndex = orderIndex
        self.word = word
        self.audioStem = audioStem.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Normalized stem used with `WordAudioPlayer` / bundle lookup.
    var playbackStem: String {
        audioStem.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
