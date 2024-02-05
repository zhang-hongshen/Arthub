//
//  ArthubApp.swift
//  Arthub
//
//  Created by 张鸿燊 on 2/2/2024.
//

import SwiftUI
import SwiftData

@main
struct ArthubApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Movie.self,
            Music.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .modelContainer(sharedModelContainer)
        
        Settings {
            SettingsView()
        }
        WindowGroup("", id: "window.progress", for: Double.self) { current in
            if let value = current.wrappedValue {
                VStack {
                    ProgressView(value: value) {
                        Text(value.rounded().formatted())
                    }
                    .padding(10)
                    .frame(width: 300, height: 60)
                    .fixedSize()
                    Button("common.cancel") {
                        
                    }
                }
                .padding(10)
            }
        }
        .defaultPosition(.center)
        .windowResizability(.contentSize)
    }
}
