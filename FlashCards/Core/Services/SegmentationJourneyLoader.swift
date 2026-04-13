//
//  SegmentationJourneyLoader.swift
//  FlashCards
//
//  Loads bundled `segmentation_seed_146.json` and resolves five visit pairs per `soundOrderIndex`.
//

import Foundation

enum SegmentationJourneyLoader {
    private static let cacheLock = NSLock()
    private static var cachedRoot: SegmentationJourneySeedRoot?

    static func clearCacheForTesting() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cachedRoot = nil
    }

    /// Ordered visit index (1…5) and two words per pair. Falls back to stage‑4 words when the seed has no row.
    static func fiveVisitWordPairs(soundOrderIndex: Int) -> [(visitIndex: Int, word0: String, word1: String)] {
        if let fromSeed = pairsFromBundledSeed(soundOrderIndex: soundOrderIndex) {
            return fromSeed
        }
        return syntheticPairs(soundOrderIndex: soundOrderIndex)
    }

    private static func pairsFromBundledSeed(soundOrderIndex: Int) -> [(visitIndex: Int, word0: String, word1: String)]? {
        guard let sound = loadRoot()?.sounds.first(where: { $0.orderIndex == soundOrderIndex }) else { return nil }
        let sorted = sound.visitPairs.sorted { $0.visitIndex < $1.visitIndex }
        guard sorted.count >= 5 else { return nil }
        var out: [(Int, String, String)] = []
        out.reserveCapacity(5)
        for pair in sorted.prefix(5) {
            guard pair.items.count >= 2 else { return nil }
            let w0 = normalizedWord(pair.items[0].word)
            let w1 = normalizedWord(pair.items[1].word)
            guard !w0.isEmpty, !w1.isEmpty else { return nil }
            out.append((pair.visitIndex, w0, w1))
        }
        guard out.count == 5 else { return nil }
        return out
    }

    private static func syntheticPairs(soundOrderIndex: Int) -> [(visitIndex: Int, word0: String, word1: String)] {
        var words = ConstructionIndexG1Loader.stage4FirstFiveWords(forSoundOrderIndex: soundOrderIndex)
            .map { normalizedWord($0) }
            .filter { !$0.isEmpty }
        if words.count < 2 {
            if let entry = try? LearningProgressionEngine.curriculumRoot().sounds.first(where: { $0.orderIndex == soundOrderIndex }) {
                let w = normalizedWord(entry.exampleWord)
                if !w.isEmpty { words = [w, w] }
            }
        }
        if words.isEmpty {
            return (1...5).map { (visitIndex: $0, word0: "a", word1: "at") }
        }
        if words.count == 1 {
            words = [words[0], words[0]]
        }
        while words.count < 10 {
            words.append(contentsOf: words)
        }
        return (0..<5).map { i in
            (visitIndex: i + 1, word0: words[i * 2], word1: words[i * 2 + 1])
        }
    }

    private static func loadRoot() -> SegmentationJourneySeedRoot? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cachedRoot {
            return cachedRoot
        }
        let name = "segmentation_seed_146"
        let ext = "json"
        guard let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Seed")
            ?? Bundle.main.url(forResource: name, withExtension: ext) else {
            return nil
        }
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONDecoder().decode(SegmentationJourneySeedRoot.self, from: data) else {
            return nil
        }
        cachedRoot = root
        return root
    }

    private static func normalizedWord(_ raw: String) -> String {
        ConstructionDataSource.normalizedWordKey(raw)
    }
}
