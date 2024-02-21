//
//  ArthubApp.swift
//  Arthub
//
//  Created by 张鸿燊 on 2/2/2024.
//

import SwiftUI
import SwiftData
import TMDb

@main
struct ArthubApp: App {
    var sharedModelContainer: ModelContainer
    
    init() {
        self.sharedModelContainer = {
            let schema = Schema([
                MovieMetrics.self,
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }()
        TMDbConfiguration.configure(TMDbConfiguration.shared)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .applyUserSettings()
                    
        }
        .windowResizability(.contentMinSize)
        .defaultPosition(.center)
        .modelContainer(sharedModelContainer)
        
        Settings {
            SettingsView()
                .applyUserSettings()
        }
        
        ProgressWindow()
            .defaultPosition(.center)
            .windowResizability(.contentSize)
        
        ErrorWindow()
            .defaultPosition(.center)
            .windowResizability(.contentSize)
    }
}
