//
//  PhonicsModulePOCDTO.swift
//  FlashCards
//
//  Decodes `Resources/Seed/phonics_modules_poc.json` (POC for Segmentation + Construction).
//  One exercise = one target word + ordered segments (letters for now; digraphs later as one segment, e.g. "sh").
//

import Foundation

struct PhonicsModulePOCRoot: Codable, Sendable {
    let schemaVersion: Int
    let segmentation: [PhonicsModuleExerciseDTO]
    let construction: [PhonicsModuleExerciseDTO]
}

struct PhonicsModuleExerciseDTO: Codable, Sendable, Identifiable {
    let id: String
    let orderIndex: Int
    /// Whole word (lowercase in seed data).
    let word: String
    /// Left-to-right grapheme chunks; concatenating should equal `word` for this POC.
    let segments: [String]
}

enum PhonicsModulePOCLoader {
    enum LoadError: Error {
        case missingFile
        case emptyData
    }

    /// Loads and decodes the bundled POC file. Does not persist; safe to call from previews/tests.
    static func load(from bundle: Bundle = .main) throws -> PhonicsModulePOCRoot {
        let name = "phonics_modules_poc"
        let ext = "json"
        guard let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "Seed")
            ?? bundle.url(forResource: name, withExtension: ext) else {
            throw LoadError.missingFile
        }
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else { throw LoadError.emptyData }
        return try JSONDecoder().decode(PhonicsModulePOCRoot.self, from: data)
    }
}
