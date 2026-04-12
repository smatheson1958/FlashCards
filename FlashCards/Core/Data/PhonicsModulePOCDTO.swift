//
//  PhonicsModulePOCDTO.swift
//  FlashCards
//
//  Decodes `Resources/Seed/segmentation.json` (segmentation + construction word lists).
//  One exercise = one target word + ordered segments (letters for now; digraphs later as one segment, e.g. "sh").
//

import Foundation

struct PhonicsModulePOCRoot: Codable, Sendable {
    let schemaVersion: Int
    let segmentation: [PhonicsModuleExerciseDTO]
    let construction: [PhonicsModuleExerciseDTO]
}

struct PhonicsModuleExerciseDTO: Sendable, Identifiable {
    let id: String
    let orderIndex: Int
    /// Whole word (lowercase in seed data).
    let word: String

    /// Raw `segments` from JSON when present; omitted or `null` is allowed for backward compatibility.
    private let rawSegments: [String]?

    /// Left-to-right grapheme chunks from JSON when non-empty after trimming; otherwise one character per Unicode scalar in `word` (lowercased, trimmed).
    var segments: [String] {
        let trimmed = (rawSegments ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if !trimmed.isEmpty { return trimmed }
        return Self.fallbackGraphemes(for: word)
    }

    /// Memberwise initializer for previews and tests (does not use JSON).
    init(id: String, orderIndex: Int, word: String, segments: [String]? = nil) {
        self.id = id
        self.orderIndex = orderIndex
        self.word = word
        self.rawSegments = segments
    }

    private static func fallbackGraphemes(for word: String) -> [String] {
        let key = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return [] }
        return key.map { String($0) }
    }
}

extension PhonicsModuleExerciseDTO: Codable {
    enum CodingKeys: String, CodingKey {
        case id, orderIndex, word, segments
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        orderIndex = try c.decode(Int.self, forKey: .orderIndex)
        word = try c.decode(String.self, forKey: .word)
        rawSegments = try c.decodeIfPresent([String].self, forKey: .segments)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(orderIndex, forKey: .orderIndex)
        try c.encode(word, forKey: .word)
        try c.encode(segments, forKey: .segments)
    }
}

enum PhonicsModulePOCLoader {
    enum LoadError: Error {
        case missingFile
        case emptyData
    }

    /// Loads and decodes the bundled POC file. Does not persist; safe to call from previews/tests.
    static func load(from bundle: Bundle = .main) throws -> PhonicsModulePOCRoot {
        let name = "segmentation"
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
