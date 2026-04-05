//
//  FlashCardsApp.swift
//  FlashCards
//
//  Created by scott matheson on 05/04/2026.
//

import SwiftData
import SwiftUI

@main
struct FlashCardsApp: App {
    private let modelContainer: ModelContainer

    init() {
        let schema = Schema([CardProgress.self, WordCard.self])
        let configuration = ModelConfiguration()
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
