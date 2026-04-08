//
//  SimpleConstructionEngine.swift
//  FlashCards
//

import Foundation

/// One tappable tile (unique id so duplicate labels like two `g` in “egg” are distinct buttons).
struct ConstructionPoolTile: Identifiable, Equatable, Sendable {
    let id: UUID
    let label: String
}

/// Fill slots left to right; wrong taps do not remove tiles from the pool.
struct SimpleConstructionEngine: Equatable, Sendable {
    let targetSegments: [String]
    private let distractorLabels: [String]

    private(set) var pool: [ConstructionPoolTile]
    private(set) var progress: Int

    init(targetSegments: [String], distractorLabels: [String]) {
        let target = targetSegments.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        self.targetSegments = target
        self.distractorLabels = distractorLabels
        self.progress = 0
        self.pool = Self.buildPool(target: target, distractors: distractorLabels)
    }

    var slotCount: Int { targetSegments.count }

    var isComplete: Bool {
        !targetSegments.isEmpty && progress >= targetSegments.count
    }

    /// Filled label for a slot index, or `nil` if still empty.
    func labelAtSlot(_ index: Int) -> String? {
        guard index >= 0, index < targetSegments.count else { return nil }
        return index < progress ? targetSegments[index] : nil
    }

    mutating func reset() {
        progress = 0
        pool = Self.buildPool(target: targetSegments, distractors: distractorLabels)
    }

    enum TapResult: Equatable, Sendable {
        case accepted
        case wrong
        case ignoredComplete
        case ignoredUnknownTile
    }

    mutating func handleTap(tileID: UUID) -> TapResult {
        guard !isComplete else { return .ignoredComplete }
        guard let idx = pool.firstIndex(where: { $0.id == tileID }) else { return .ignoredUnknownTile }
        let label = pool[idx].label
        let expected = targetSegments[progress]
        guard Self.labelsMatch(label, expected) else { return .wrong }

        pool.remove(at: idx)
        progress += 1
        return .accepted
    }

    private static func labelsMatch(_ tapped: String, _ expected: String) -> Bool {
        tapped.compare(expected, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    private static func buildPool(target: [String], distractors: [String]) -> [ConstructionPoolTile] {
        var tiles: [ConstructionPoolTile] = target.map { ConstructionPoolTile(id: UUID(), label: $0) }
        for d in distractors {
            let t = d.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { continue }
            tiles.append(ConstructionPoolTile(id: UUID(), label: t))
        }
        tiles.shuffle()
        return tiles
    }
}

// MARK: - Distractors (testable, no UI)

enum ConstructionTilePoolBuilder: Sendable {
    /// Letters and a few digraphs; skips labels already present in the target.
    static func distractorLabels(forTargetSegments target: [String], count: Int) -> [String] {
        let normalizedTarget = Set(target.map { $0.lowercased() })
        let candidates = [
            "p", "m", "b", "n", "r", "l", "w", "g", "d", "s", "t", "k", "v", "z",
            "sh", "ch", "th", "a", "e", "i", "o", "u",
        ]
        var picked: [String] = []
        for c in candidates.shuffled() {
            guard picked.count < count else { break }
            if !normalizedTarget.contains(c.lowercased()) {
                picked.append(c)
            }
        }
        return picked
    }

    static func distractorCount(forSegmentCount segmentCount: Int) -> Int {
        switch segmentCount {
        case ...2:
            return FlashCardsConstants.constructionDistractorCountShortWord
        case 3:
            return FlashCardsConstants.constructionDistractorCountShortWord
        default:
            return FlashCardsConstants.constructionDistractorCountLongWord
        }
    }
}
