//
//  ContentView.swift
//  FlashCards
//
//  Created by scott matheson on 05/04/2026.
//

import SwiftData
import SwiftUI

private enum RootTab: Hashable {
    case exercises
    case currentDeck
    #if DEBUG
    case debug
    #endif
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var session = StudySessionStore()
    @State private var isPreparingLibrary = true
    @State private var showLibraryLoadAlert = false
    @State private var libraryLoadErrorMessage = ""
    /// Keep launch (and any ambiguous tab state) on **Exercises** — the main entry screen.
    @State private var selectedTab: RootTab = .exercises

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Exercises", systemImage: "square.grid.2x2", value: RootTab.exercises) {
                NavigationStack {
                    ExerciseHomeView(session: session, isLibraryPreparing: isPreparingLibrary)
                }
            }

            Tab("Current deck", systemImage: "square.stack", value: RootTab.currentDeck) {
                NavigationStack {
                    CurrentDeckListView()
                }
            }

            #if DEBUG
            Tab("Debug", systemImage: "ladybug", value: RootTab.debug) {
                NavigationStack {
                    DebugTabView()
                }
            }
            #endif
        }
        .task {
            await prepareLibrary()
        }
        .onReceive(NotificationCenter.default.publisher(for: .phonicsDeckDidRebuildFromSeed)) { _ in
            session.resetSession()
        }
        .alert("Couldn’t load library", isPresented: $showLibraryLoadAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(libraryLoadErrorMessage)
        }
    }

    @MainActor
    private func prepareLibrary() async {
        isPreparingLibrary = true
        defer { isPreparingLibrary = false }
        showLibraryLoadAlert = false
        do {
            try SeedImporter.importIfNeeded(context: modelContext)
            try WordsSeedImporter.importIfNeeded(context: modelContext)
        } catch {
            libraryLoadErrorMessage = error.localizedDescription
            showLibraryLoadAlert = true
        }
        await Task.yield()
    }
}

#Preview {
    let memory = ModelConfiguration(isStoredInMemoryOnly: true)
    let schema = Schema([
        CardProgress.self,
        WordCard.self,
        ModeWordProgress.self,
        SegmentationSoundModuleProgress.self,
        SegmentationProgressEvent.self,
    ])
    let container = try! ModelContainer(for: schema, configurations: memory)
    return ContentView()
        .modelContainer(container)
}
