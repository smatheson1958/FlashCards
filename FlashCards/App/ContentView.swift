//
//  ContentView.swift
//  FlashCards
//
//  Created by scott matheson on 05/04/2026.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var session = StudySessionStore()
    @State private var isPreparingLibrary = true
    @State private var showLibraryLoadAlert = false
    @State private var libraryLoadErrorMessage = ""

    var body: some View {
        TabView {
            NavigationStack {
                FlashCardStudyView(session: session, isLibraryPreparing: isPreparingLibrary)
                    .navigationTitle("Study")
                    .navigationBarTitleDisplayMode(.inline)
                    .studyAppearanceToolbar()
            }
            .tabItem {
                Label("Study", systemImage: "rectangle.on.rectangle.angled")
            }

            NavigationStack {
                CurrentDeckListView()
            }
            .tabItem {
                Label("Current deck", systemImage: "square.stack")
            }

            NavigationStack {
                SuccessfulListView()
            }
            .tabItem {
                Label("Successful", systemImage: "checkmark.circle")
            }

            NavigationStack {
                WordStudyView(isLibraryPreparing: isPreparingLibrary)
                    .navigationTitle("Words")
                    .navigationBarTitleDisplayMode(.inline)
                    .studyAppearanceToolbar()
            }
            .tabItem {
                Label("Words", systemImage: "text.bubble")
            }
        }
        .task {
            await prepareLibrary()
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
    let schema = Schema([CardProgress.self, WordCard.self])
    let container = try! ModelContainer(for: schema, configurations: memory)
    return ContentView()
        .modelContainer(container)
}
