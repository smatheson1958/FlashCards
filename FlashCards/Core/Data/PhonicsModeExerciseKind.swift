//
//  PhonicsModeExerciseKind.swift
//  FlashCards
//

import Foundation

/// Construction vs segmentation practice; stored on `ModeWordProgress`.
enum PhonicsModeExerciseKind: String, Codable, CaseIterable, Sendable {
    case construction
    case segmentation
}
