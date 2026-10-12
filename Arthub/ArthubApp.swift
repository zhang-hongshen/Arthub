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
    @State private var state =  WindowState()
    @State private var videoPlayer = ArthubVideoPlayer()
    @State private var audioPlayer = ArthubAudioPlayer()

    init() {
        UserDefaults.standard.register(defaults: [UserDefaults.library: UserDefaults.defaultLibraries])
        TMDbConfiguration.configure(TMDbConfiguration(apiKey: ProcessInfo.processInfo.environment["tmdb_api_key"] ?? ""))
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
        .modelContainer(WatchProgressStore.shared.container)
        .environment(state)
        .environment(videoPlayer)
        .environment(audioPlayer)
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
