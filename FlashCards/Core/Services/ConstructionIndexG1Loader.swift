//
//  ConstructionIndexG1Loader.swift
//  FlashCards
//
//  Bundled `construction_index_g1_foundation.json` defines **foundation** construction/segmentation
//  word lists and grapheme units (sound ids 1…30 in that file). The master curriculum has 146
//  sounds (`sound_units_primary_index_146.json`); for order indices **without** a row here,
//  `LearningProgressionEngine` falls back to each sound’s single `exampleWord` until a full
//  construction index exists for all sounds.
//

import Foundation

enum ConstructionIndexG1Loader {
    enum LoadError: Error {
        case missingFile
        case emptyData
        case decodeFailed
    }

    private static let fileName = "construction_index_g1_foundation"
    private static let fileExtension = "json"

    private static var cachedRoot: ConstructionIndexG1Root?
    private static let lock = NSLock()

    static func clearCacheForTesting() {
        lock.lock()
        defer { lock.unlock() }
        cachedRoot = nil
    }

    static func load(from bundle: Bundle = .main) throws -> ConstructionIndexG1Root {
        lock.lock()
        defer { lock.unlock() }
        if let cachedRoot {
            return cachedRoot
        }
        guard let url = bundle.url(forResource: fileName, withExtension: fileExtension, subdirectory: "Seed")
            ?? bundle.url(forResource: fileName, withExtension: fileExtension) else {
            throw LoadError.missingFile
        }
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else { throw LoadError.emptyData }
        do {
            let root = try JSONDecoder().decode(ConstructionIndexG1Root.self, from: data)
            cachedRoot = root
            return root
        } catch {
            throw LoadError.decodeFailed
        }
    }

    /// First five words from `unlocks.stage4`, in JSON order (Construction / Segmentation programme).
    static func stage4FirstFiveWords(forSoundOrderIndex orderIndex: Int) -> [String] {
        guard let item = item(forSoundOrderIndex: orderIndex) else { return [] }
        let stage4 = item.progression?.unlocks?.stage4 ?? []
        let trimmed = stage4.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return Array(trimmed.prefix(5))
    }

    static func item(forSoundOrderIndex orderIndex: Int) -> ConstructionIndexG1ItemDTO? {
        guard let root = try? load() else { return nil }
        return root.items.first { $0.id == orderIndex }
    }

    /// Ordered grapheme units for `word` in this sound’s `constructionSets` (used for Construction and Segmentation).
    static func graphemeUnits(forSoundOrderIndex orderIndex: Int, word: String) -> [String]? {
        guard let item = item(forSoundOrderIndex: orderIndex) else { return nil }
        let key = ConstructionDataSource.normalizedWordKey(word)
        guard !key.isEmpty else { return nil }
        for set in item.constructionSets {
            let w = ConstructionDataSource.normalizedWordKey(set.word)
            if w == key {
                let units = set.graphemeUnits.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                return units.isEmpty ? nil : units
            }
        }
        return nil
    }
}
