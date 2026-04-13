//
//  SeedImporter.swift
//  FlashCards
//

import Foundation
import SwiftData

enum SeedImporter {
    private static let didSeedKey = "FlashCards.didSeedFromJSON"

    static var hasSeeded: Bool {
        get { UserDefaults.standard.bool(forKey: didSeedKey) }
        set { UserDefaults.standard.set(newValue, forKey: didSeedKey) }
    }

    /// If the store was wiped but the seed flag stayed on, allow importing again.
    static func repairSeededFlagIfPhonicsStoreEmpty(context: ModelContext) {
        let count = phonicsCardCount(context: context)
        if count == 0, hasSeeded {
            hasSeeded = false
        }
    }

    private static func phonicsCardCount(context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<CardProgress>()
        return (try? context.fetch(descriptor).count) ?? 0
    }

    static func importIfNeeded(context: ModelContext) throws {
        repairSeededFlagIfPhonicsStoreEmpty(context: context)
        let count = phonicsCardCount(context: context)
        if count > 0 {
            if !hasSeeded { hasSeeded = true }
            return
        }
        guard !hasSeeded else { return }

        let dtos = try loadPhonicsSeedDTOs()
        guard !dtos.isEmpty else { throw SeedError.emptyJSON }

        let sorted = dtos.sorted { $0.orderIndex < $1.orderIndex }
        let introLimit = min(
            FlashCardsConstants.initialSoundDeckIntroLimit,
            FlashCardsConstants.currentDeckTargetCount,
            sorted.count
        )

        for (idx, dto) in sorted.enumerated() {
            let state = DeckManager.bootstrapDeckState(zeroBasedIndex: idx, introLimit: introLimit)
            let card = CardProgress(
                cardID: dto.id,
                orderIndex: dto.orderIndex,
                sound: dto.sound,
                word: dto.word,
                deckState: state
            )
            if state == .currentDeck {
                card.introducedDate = Date()
            }
            context.insert(card)
        }

        try context.save()
        hasSeeded = true
    }

    /// Prefer the master `sound_units_primary_index_146.json` (ordered 1…N); fall back to `cards.json` or embedded JSON.
    private static func loadPhonicsSeedDTOs() throws -> [SeedCardDTO] {
        if let fromMaster = loadDTOsFromSoundUnitsPrimaryIndex() {
            return fromMaster
        }

        let data = try loadPhonicsSeedDataLegacy()
        return try JSONDecoder().decode([SeedCardDTO].self, from: data)
    }

    private static func loadDTOsFromSoundUnitsPrimaryIndex() -> [SeedCardDTO]? {
        guard let root = try? SoundUnitsPrimaryIndexLoader.load() else { return nil }
        let sorted = root.sounds.sorted { $0.orderIndex < $1.orderIndex }
        guard !sorted.isEmpty else { return nil }
        return sorted.map { entry in
            SeedCardDTO(
                id: phonicsCardID(orderIndex: entry.orderIndex),
                orderIndex: entry.orderIndex,
                sound: entry.soundUnit.trimmingCharacters(in: .whitespacesAndNewlines),
                word: entry.exampleWord.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    private static func phonicsCardID(orderIndex: Int) -> String {
        String(format: "su_%03d", orderIndex)
    }

    private static func loadPhonicsSeedDataLegacy() throws -> Data {
        if let url = Bundle.main.url(forResource: "cards", withExtension: "json", subdirectory: "Seed")
            ?? Bundle.main.url(forResource: "cards", withExtension: "json") {
            return try Data(contentsOf: url)
        }
        guard let embedded = embeddedPhonicsJSON.data(using: .utf8) else {
            throw SeedError.missingBundleFile
        }
        return embedded
    }

    /// Used when `cards.json` is not copied into the app bundle (target membership).
    private static let embeddedPhonicsJSON = """
    [
      { "id": "card_001", "orderIndex": 1, "sound": "a", "word": "cat" },
      { "id": "card_002", "orderIndex": 2, "sound": "b", "word": "bat" },
      { "id": "card_003", "orderIndex": 3, "sound": "c", "word": "cup" },
      { "id": "card_004", "orderIndex": 4, "sound": "d", "word": "dog" },
      { "id": "card_005", "orderIndex": 5, "sound": "e", "word": "egg" },
      { "id": "card_006", "orderIndex": 6, "sound": "f", "word": "fish" },
      { "id": "card_007", "orderIndex": 7, "sound": "g", "word": "goat" },
      { "id": "card_008", "orderIndex": 8, "sound": "h", "word": "hat" },
      { "id": "card_009", "orderIndex": 9, "sound": "i", "word": "igloo" },
      { "id": "card_010", "orderIndex": 10, "sound": "j", "word": "jam" },
      { "id": "card_011", "orderIndex": 11, "sound": "k", "word": "kite" },
      { "id": "card_012", "orderIndex": 12, "sound": "l", "word": "leg" },
      { "id": "card_013", "orderIndex": 13, "sound": "m", "word": "man" },
      { "id": "card_014", "orderIndex": 14, "sound": "n", "word": "net" },
      { "id": "card_015", "orderIndex": 15, "sound": "o", "word": "dog" },
      { "id": "card_016", "orderIndex": 16, "sound": "p", "word": "pen" },
      { "id": "card_017", "orderIndex": 17, "sound": "q", "word": "queen" },
      { "id": "card_018", "orderIndex": 18, "sound": "r", "word": "rat" },
      { "id": "card_019", "orderIndex": 19, "sound": "s", "word": "sun" },
      { "id": "card_020", "orderIndex": 20, "sound": "t", "word": "top" }
    ]
    """

    enum SeedError: Error {
        case missingBundleFile
        case emptyJSON
    }

    #if DEBUG
    /// Deletes all `CardProgress` rows and re-imports from the bundled phonics seed (same path as first launch).
    static func rebuildPhonicsDeckFromSeed(context: ModelContext) throws {
        let descriptor = FetchDescriptor<CardProgress>()
        let all = (try? context.fetch(descriptor)) ?? []
        for card in all {
            context.delete(card)
        }
        ModeWordProgressService.deleteAll(context: context)
        SegmentationModuleProgressService.deleteAll(context: context)
        try context.save()
        hasSeeded = false
        clearPhonicsBundledCachesAfterDevelopmentRebuild()
        try importIfNeeded(context: context)
    }

    /// In-memory JSON / curriculum caches so the next read matches the bundle after a rebuild or fixture change.
    private static func clearPhonicsBundledCachesAfterDevelopmentRebuild() {
        LearningProgressionEngine.clearCurriculumCacheForTesting()
        ConstructionIndexG1Loader.clearCacheForTesting()
        ConstructionDataSource.clearCacheForTesting()
        SegmentationDataSource.clearCacheForTesting()
        SegmentationJourneyLoader.clearCacheForTesting()
    }
    #endif
}
