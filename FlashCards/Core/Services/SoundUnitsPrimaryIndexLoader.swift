//
//  SoundUnitsPrimaryIndexLoader.swift
//  FlashCards
//

import Foundation

enum SoundUnitsPrimaryIndexLoader {
    enum LoadError: Error {
        case missingFile
        case emptyData
        case decodeFailed
    }

    /// Canonical curriculum file (`sound_units_primary_index_146_v1.json` is merge-input only; not loaded by the app).
    private static let fileName = "sound_units_primary_index_146"
    private static let fileExtension = "json"

    /// Loads and decodes the bundled master index. Safe to call from any actor; result can be cached.
    static func load(from bundle: Bundle = .main) throws -> SoundUnitsPrimaryIndexRoot {
        guard let url = bundle.url(forResource: fileName, withExtension: fileExtension, subdirectory: "Seed")
            ?? bundle.url(forResource: fileName, withExtension: fileExtension) else {
            throw LoadError.missingFile
        }
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else { throw LoadError.emptyData }
        do {
            return try JSONDecoder().decode(SoundUnitsPrimaryIndexRoot.self, from: data)
        } catch {
            throw LoadError.decodeFailed
        }
    }
}
