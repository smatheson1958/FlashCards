//
//  CardProgress.swift
//  FlashCards
//

import Foundation
import SwiftData

@Model
final class CardProgress {
    @Attribute(.unique) var cardID: String
    var orderIndex: Int
    var sound: String
    var word: String
    var deckStateRaw: String
    var masteryCorrectCount: Int
    var reviewPriority: Double
    var lifetimeCorrectCount: Int
    var lifetimeWrongCount: Int
    var introducedDate: Date?
    var lastReviewedDate: Date?
    var imageSourceRaw: String
    var userImagePath: String?
    var symbolName: String?
    var bundledImageName: String?

    init(
        cardID: String,
        orderIndex: Int,
        sound: String,
        word: String,
        deckState: DeckState,
        masteryCorrectCount: Int = 0,
        reviewPriority: Double = 1,
        imageSource: CardImageSource = .none
    ) {
        self.cardID = cardID
        self.orderIndex = orderIndex
        self.sound = sound
        self.word = word
        self.deckStateRaw = deckState.rawValue
        self.masteryCorrectCount = masteryCorrectCount
        self.reviewPriority = reviewPriority
        self.lifetimeCorrectCount = 0
        self.lifetimeWrongCount = 0
        self.introducedDate = nil
        self.lastReviewedDate = nil
        self.imageSourceRaw = imageSource.rawValue
        self.userImagePath = nil
        self.symbolName = nil
        self.bundledImageName = nil
    }

    var deckState: DeckState {
        get { DeckState(rawValue: deckStateRaw) ?? .notIntroduced }
        set { deckStateRaw = newValue.rawValue }
    }

    var imageSource: CardImageSource {
        get { CardImageSource(rawValue: imageSourceRaw) ?? .none }
        set { imageSourceRaw = newValue.rawValue }
    }
}
