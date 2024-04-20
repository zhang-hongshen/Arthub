//
//  ArthubApp.swift
//  Arthub
//
//  Created by 张鸿燊 on 2/2/2024.
//

import SwiftUI
import SwiftData
import TMDb

@ModelActor
actor CachedDataHandler {
    
    private(set) static var shared: CachedDataHandler!
    
    static func configure(modelContainer: ModelContainer) {
        shared = CachedDataHandler(modelContainer: modelContainer)
    }
    
    func fetch<T>(_ descriptor: FetchDescriptor<T>) throws -> [T] where T : PersistentModel {
        return try modelContext.fetch(descriptor)
    }
    
    func fetch<T>(_ descriptor: FetchDescriptor<T>, batchSize: Int) throws -> FetchResultsCollection<T> where T : PersistentModel  {
        return try modelContext.fetch(descriptor, batchSize: batchSize)
    }
    
    func insert<T>(_ model: T) throws where T : PersistentModel  {
        modelContext.insert(model)
        try modelContext.save()
    }
    
    func delete<T>(_ model: T) throws where T : PersistentModel {
        try delete([model])
    }
    
    func delete<T>(_ models: [T]) throws where T : PersistentModel {
        for model in models {
            modelContext.delete(model)
        }
        try modelContext.save()
    }
    
    func delete<T>(model: T.Type, where predicate: Predicate<T>? = nil, includeSubclasses: Bool = true) throws where T : PersistentModel {
        try modelContext.delete(model: model, where: predicate, includeSubclasses: includeSubclasses)
        try modelContext.save()
    }
}

@main
struct ArthubApp: App {
    var sharedModelContainer: ModelContainer
    
    init() {
        
        self.sharedModelContainer = {
            let schema = Schema([
                UserMetrics.self,
                LibraryDetail.self,
                FeedDetail.self
            ])
            // MARK: change isStoredInMemoryOnly to true when release
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }()
        CachedDataHandler.configure(modelContainer: sharedModelContainer)
        TMDbConfiguration.configure(apiKey: ProcessInfo.processInfo.environment["tmdb_api_key"] ?? "")
    }
    
    var body: some Scene {
        Group {
            WindowGroup {
                ContentView()
                    .applyUserSettings()
            }
#if os(macOS)
            Settings {
                SettingsView()
                    .applyUserSettings()
                    
            }
#endif
        }
        .modelContainer(sharedModelContainer)
        #if !os(tvOS)
        .windowResizability(.contentMinSize)
        .commands {
            SidebarCommands()
            ToolbarCommands()
            InspectorCommands()
        }
        #endif
    }
}
