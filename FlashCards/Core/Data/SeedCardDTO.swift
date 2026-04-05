//
//  SeedCardDTO.swift
//  FlashCards
//

import Foundation

struct SeedCardDTO: Codable, Sendable {
    let id: String
    let orderIndex: Int
    let sound: String
    let word: String
}
