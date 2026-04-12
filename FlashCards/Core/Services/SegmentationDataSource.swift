//
//  SegmentationDataSource.swift
//  FlashCards
//

import Foundation

/// Resolves ordered graphemes for **segmentation** from bundled `segmentation.json` (`segmentation` entries), before the G1 construction index or construction seed fallback.
enum SegmentationDataSource {
    private static var cachedMap: [String: [String]]?
    private static let lock = NSLock()

    static func normalizedWordKey(_ word: String) -> String {
        word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Clears the in-memory map from `segmentation.json` (e.g. after a DEBUG deck rebuild or bundle swap).
    static func clearCacheForTesting() {
        lock.lock()
        defer { lock.unlock() }
        cachedMap = nil
    }

    /// Segments defined in the seed for this word, or empty when the word is not listed.
    static func segments(forWord word: String) -> [String] {
        let key = normalizedWordKey(word)
        guard !key.isEmpty else { return [] }

        lock.lock()
        defer { lock.unlock() }

        if cachedMap == nil {
            cachedMap = loadSegmentationMap()
        }
        return cachedMap?[key] ?? []
    }

    /// Seed segmentation first, then `construction_index_g1_foundation.json`, then construction seed / per-letter fallback.
    static func resolvedSegments(forWord word: String, soundOrderIndex: Int) -> [String] {
        let fromSeed = segments(forWord: word)
        if !fromSeed.isEmpty { return fromSeed }
        if let g = ConstructionIndexG1Loader.graphemeUnits(forSoundOrderIndex: soundOrderIndex, word: word), !g.isEmpty {
            return g
        }
        return ConstructionDataSource.segments(forWord: word)
    }

    private static func loadSegmentationMap() -> [String: [String]] {
        guard let root = try? PhonicsModulePOCLoader.load() else { return [:] }
        var map: [String: [String]] = [:]
        for ex in root.segmentation {
            let w = normalizedWordKey(ex.word)
            guard !w.isEmpty else { continue }
            let segs = ex.segments.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            guard !segs.isEmpty else { continue }
            map[w] = segs
        }
        return map
    }
}
