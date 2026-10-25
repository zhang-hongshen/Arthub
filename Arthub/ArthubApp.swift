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
    @State private var videoPlayer: ArthubVideoPlayer
    @State private var audioPlayer: ArthubAudioPlayer
    @State private var musicViewModel: MusicViewModel
    @State private var agentTools: AgentTools
    #if os(macOS)
    /// The MCP server for AI agents (`AgentServer`).
    private let agentServer: AgentServer
    #endif

    init() {
        UserDefaults.standard.register(defaults: [UserDefaults.library: UserDefaults.defaultLibraries])
        TMDbConfiguration.configure(TMDbConfiguration(apiKey: ProcessInfo.processInfo.environment["tmdb_api_key"] ?? ""))
        let videoPlayer = ArthubVideoPlayer()
        let audioPlayer = ArthubAudioPlayer()
        let musicViewModel = MusicViewModel()
        let agentTools = AgentTools(audioPlayer: audioPlayer, videoPlayer: videoPlayer, music: musicViewModel)
        _videoPlayer = State(initialValue: videoPlayer)
        _audioPlayer = State(initialValue: audioPlayer)
        _musicViewModel = State(initialValue: musicViewModel)
        _agentTools = State(initialValue: agentTools)
        #if os(macOS)
        // Started here rather than from a window, so it also runs when an agent launches the app
        // in the background. The app works without it if it cannot listen.
        agentServer = AgentServer(tools: agentTools)
        do {
            try agentServer.start()
        } catch {
            print("The agent server did not start: \(error)")
        }
        #endif
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
        .environment(musicViewModel)
        .environment(agentTools)
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
