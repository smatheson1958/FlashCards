//
//  WordSeedDTO.swift
//  FlashCards
//

import Foundation

/// Bundled resource shape for the **words** feature — independent from phonics `cards.json`.
struct WordSeedDTO: Codable, Sendable {
    let id: String
    let orderIndex: Int
    let word: String
    /// Base name for `\(audioStem).wav` in the bundle (may differ from spelling of `word`).
    let audioStem: String
}
