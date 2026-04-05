//
//  WordsSeedImporter.swift
//  FlashCards
//

import Foundation
import SwiftData

enum WordsSeedImporter {
    private static let didSeedKey = "FlashCards.didSeedWordCardsJSON"

    static var hasSeeded: Bool {
        get { UserDefaults.standard.bool(forKey: didSeedKey) }
        set { UserDefaults.standard.set(newValue, forKey: didSeedKey) }
    }

    static func repairSeededFlagIfWordsStoreEmpty(context: ModelContext) {
        let count = wordCardCount(context: context)
        if count == 0, hasSeeded {
            hasSeeded = false
        }
    }

    private static func wordCardCount(context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<WordCard>()
        return (try? context.fetch(descriptor).count) ?? 0
    }

    /// Seeds `WordCard` rows from bundled `words.json` (separate from phonics `cards.json`).
    static func importIfNeeded(context: ModelContext) throws {
        repairSeededFlagIfWordsStoreEmpty(context: context)
        let count = wordCardCount(context: context)
        if count > 0 {
            if !hasSeeded { hasSeeded = true }
            return
        }
        guard !hasSeeded else { return }

        let data = try loadWordsSeedData()
        let dtos = try JSONDecoder().decode([WordSeedDTO].self, from: data)
        guard !dtos.isEmpty else { throw WordsSeedError.emptyJSON }

        try removeAllWordCards(context: context)

        let sorted = dtos.sorted { $0.orderIndex < $1.orderIndex }
        for dto in sorted {
            let stem = dto.audioStem
            let card = WordCard(
                wordID: dto.id,
                orderIndex: dto.orderIndex,
                word: dto.word,
                audioStem: stem
            )
            context.insert(card)
        }

        try context.save()
        hasSeeded = true
    }

    private static func loadWordsSeedData() throws -> Data {
        if let url = Bundle.main.url(forResource: "words", withExtension: "json", subdirectory: "Seed")
            ?? Bundle.main.url(forResource: "words", withExtension: "json") {
            return try Data(contentsOf: url)
        }
        guard let embedded = embeddedWordsJSON.data(using: .utf8) else {
            throw WordsSeedError.missingBundleFile
        }
        return embedded
    }

    private static let embeddedWordsJSON = """
    [
      { "id": "word_001", "orderIndex": 1, "word": "cat", "audioStem": "cat" },
      { "id": "word_002", "orderIndex": 2, "word": "bat", "audioStem": "bat" },
      { "id": "word_003", "orderIndex": 3, "word": "cup", "audioStem": "cup" },
      { "id": "word_004", "orderIndex": 4, "word": "dog", "audioStem": "dog" },
      { "id": "word_005", "orderIndex": 5, "word": "egg", "audioStem": "egg" },
      { "id": "word_006", "orderIndex": 6, "word": "fish", "audioStem": "fish" },
      { "id": "word_007", "orderIndex": 7, "word": "goat", "audioStem": "goat" },
      { "id": "word_008", "orderIndex": 8, "word": "hat", "audioStem": "hat" },
      { "id": "word_009", "orderIndex": 9, "word": "igloo", "audioStem": "igloo" },
      { "id": "word_010", "orderIndex": 10, "word": "jam", "audioStem": "jam" },
      { "id": "word_011", "orderIndex": 11, "word": "kite", "audioStem": "kite" },
      { "id": "word_012", "orderIndex": 12, "word": "leg", "audioStem": "leg" },
      { "id": "word_013", "orderIndex": 13, "word": "man", "audioStem": "man" },
      { "id": "word_014", "orderIndex": 14, "word": "net", "audioStem": "net" },
      { "id": "word_015", "orderIndex": 15, "word": "dog", "audioStem": "dog" },
      { "id": "word_016", "orderIndex": 16, "word": "pen", "audioStem": "pen" },
      { "id": "word_017", "orderIndex": 17, "word": "queen", "audioStem": "queen" },
      { "id": "word_018", "orderIndex": 18, "word": "rat", "audioStem": "rat" },
      { "id": "word_019", "orderIndex": 19, "word": "sun", "audioStem": "sun" },
      { "id": "word_020", "orderIndex": 20, "word": "top", "audioStem": "top" }
    ]
    """

    private static func removeAllWordCards(context: ModelContext) throws {
        let descriptor = FetchDescriptor<WordCard>()
        let existing = try context.fetch(descriptor)
        for c in existing {
            context.delete(c)
        }
    }

    enum WordsSeedError: Error {
        case missingBundleFile
        case emptyJSON
    }
}
