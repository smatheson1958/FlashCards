//
//  SegmentationJourneyStep.swift
//  FlashCards
//

import Foundation

struct SegmentationJourneyStep: Identifiable, Hashable, Sendable {
    let id: String
    let soundOrderIndex: Int
    let visitIndex: Int
    let word: String
    let segments: [String]
}
