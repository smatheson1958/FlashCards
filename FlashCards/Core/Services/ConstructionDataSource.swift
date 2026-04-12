//
//  ConstructionDataSource.swift
//  FlashCards
//

import Foundation

/// Resolves ordered chunks for building a word from bundled `phonics_modules_poc.json` (`construction` entries), with grapheme fallback.
enum ConstructionDataSource {
    private static var cachedMap: [String: [String]]?
    private static let lock = NSLock()

    static func normalizedWordKey(_ word: String) -> String {
        word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Clears the in-memory map from `phonics_modules_poc.json` (e.g. after a DEBUG deck rebuild or bundle swap).
    static func clearCacheForTesting() {
        lock.lock()
        defer { lock.unlock() }
        cachedMap = nil
    }

    static func segments(forWord word: String) -> [String] {
        let key = normalizedWordKey(word)
        guard !key.isEmpty else { return [] }

        lock.lock()
        defer { lock.unlock() }

        if cachedMap == nil {
            cachedMap = loadConstructionMap()
        }
        if let explicit = cachedMap?[key], !explicit.isEmpty {
            return explicit
        }
        return fallbackGraphemes(from: key)
    }

    private static func loadConstructionMap() -> [String: [String]] {
        guard let root = try? PhonicsModulePOCLoader.load() else { return [:] }
        var map: [String: [String]] = [:]
        for ex in root.construction {
            let w = normalizedWordKey(ex.word)
            guard !w.isEmpty else { continue }
            let segs = ex.segments.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            guard !segs.isEmpty else { continue }
            map[w] = segs
        }
        return map
    }

    private static func fallbackGraphemes(from key: String) -> [String] {
        key.map { String($0) }
    }
}
