//
//  SoundUnitsPrimaryIndexDTO.swift
//  FlashCards
//
//  Decodes `sound_units_primary_index_146.json` — ordered sound curriculum (source of truth for order).
//

import Foundation

struct SoundUnitsPrimaryIndexRoot: Codable, Sendable {
    let version: String
    let totalSounds: Int
    let sounds: [SoundUnitEntryDTO]
}

struct SoundUnitEntryDTO: Codable, Sendable {
    let id: Int
    let orderIndex: Int
    let soundUnit: String
    let exampleWord: String
    let supportsModes: SoundSupportsModesDTO
}

struct SoundSupportsModesDTO: Codable, Sendable {
    let soundCards: Bool
    let memory: Bool
    let construction: Bool
    let segmentation: Bool
}
