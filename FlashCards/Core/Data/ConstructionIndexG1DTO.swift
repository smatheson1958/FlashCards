//
//  ConstructionIndexG1DTO.swift
//  FlashCards
//
//  Decodes `construction_index_g1_foundation.json` (Construction + Segmentation share `graphemeUnits`).
//

import Foundation

struct ConstructionIndexG1Root: Codable, Sendable {
    let version: String
    let sectionId: String?
    let sectionName: String?
    let range: ConstructionIndexG1Range?
    let items: [ConstructionIndexG1ItemDTO]
}

struct ConstructionIndexG1Range: Codable, Sendable {
    let startId: Int
    let endId: Int
}

struct ConstructionIndexG1ItemDTO: Codable, Sendable {
    let id: Int
    let soundUnit: String
    let anchorWord: String?
    let progression: ConstructionIndexG1ProgressionDTO?
    let constructionSets: [ConstructionIndexG1SetDTO]
}

struct ConstructionIndexG1ProgressionDTO: Codable, Sendable {
    let unlocks: ConstructionIndexG1UnlocksDTO?
}

struct ConstructionIndexG1UnlocksDTO: Codable, Sendable {
    let stage1: [String]?
    let stage2: [String]?
    let stage3: [String]?
    let stage4: [String]?
}

struct ConstructionIndexG1SetDTO: Codable, Sendable {
    let word: String
    let graphemeUnits: [String]
    let difficulty: Int?
    let unlockStage: Int?
}
