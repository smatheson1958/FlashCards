//
//  SegmentationJourneySeedDTO.swift
//  FlashCards
//
//  Decodes `Resources/Seed/segmentation_seed_146.json` (visit pairs per sound).
//

import Foundation

struct SegmentationJourneySeedRoot: Codable, Sendable {
    let version: String
    let sounds: [SegmentationJourneySeedSound]
}

struct SegmentationJourneySeedSound: Codable, Sendable {
    let id: String
    let orderIndex: Int
    let label: String
    let display: String?
    let visitPairs: [SegmentationJourneySeedVisitPair]
}

struct SegmentationJourneySeedVisitPair: Codable, Sendable {
    let visitIndex: Int
    let items: [SegmentationJourneySeedWordItem]
}

struct SegmentationJourneySeedWordItem: Codable, Sendable {
    let word: String
    let targetPosition: String?
}
