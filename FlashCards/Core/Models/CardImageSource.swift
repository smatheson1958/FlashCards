//
//  CardImageSource.swift
//  FlashCards
//

import Foundation

enum CardImageSource: String, Codable, CaseIterable, Sendable {
    case none
    case bundled
    case sfSymbol
    case userPhoto
}
