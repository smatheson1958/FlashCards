//
//  DeckState.swift
//  FlashCards
//

import Foundation

enum DeckState: String, Codable, CaseIterable, Sendable {
    case notIntroduced
    case currentDeck
    case successful
}
