//
//  FlashCardsApp.swift
//  FlashCards
//
//  Created by scott matheson on 05/04/2026.
//

import SwiftData
import SwiftUI
import UIKit

@main
struct FlashCardsApp: App {
    private let modelContainer: ModelContainer

    init() {
        Self.configureTabBarUnselectedGrey()

        let schema = Schema([CardProgress.self, WordCard.self, ModeWordProgress.self])
        let configuration = ModelConfiguration()
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    /// Unselected tab icons/labels: muted grey. (Custom `LabelStyle` is not supported inside tab bar items; use `Tab` + appearance.)
    private static func configureTabBarUnselectedGrey() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        let grey = UIColor.label.withAlphaComponent(0.45)
        appearance.stackedLayoutAppearance.normal.iconColor = grey
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: grey,
        ]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
