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
            ArthubCommands(audioPlayer: audioPlayer)
        }
        #endif
    }
}


extension FocusedValues {
    /// The sidebar selection of the focused window, for View ▸ Movies / TV Shows / Music.
    @Entry var selectedTab: Binding<ContentView.AppTab?>?
}

/// Menu bar commands for people who prefer the menu bar: switching sections and controlling music playback.
struct ArthubCommands: Commands {
    let audioPlayer: ArthubAudioPlayer

    @FocusedValue(\.selectedTab) private var selectedTab

    var body: some Commands {
        CommandGroup(before: .sidebar) {
            tabButton(.movies, key: "1")
            tabButton(.tvshows, key: "2")
            tabButton(.music, key: "3")
            Divider()
        }

        CommandMenu("Controls") {
            Button(audioPlayer.isPlaying ? "Pause" : "Play") {
                audioPlayer.togglePlayPause()
            }
            .disabled(audioPlayer.isPlaylistEmpty)

            Button("Next") {
                audioPlayer.nextTrack()
            }
            .keyboardShortcut(.rightArrow, modifiers: .command)
            .disabled(audioPlayer.isPlaylistEmpty)

            Button("Previous") {
                audioPlayer.previousTrack()
            }
            .keyboardShortcut(.leftArrow, modifiers: .command)
            .disabled(audioPlayer.isPlaylistEmpty)

            Divider()

            Toggle("Shuffle", isOn: Binding(
                get: { audioPlayer.shuffled },
                set: { _ in audioPlayer.toggleShuffle() }
            ))

            Picker("Repeat", selection: Binding(
                get: { audioPlayer.playerMode },
                set: { mode in
                    // The mode cycles Off → All → One, so step until it matches.
                    while audioPlayer.playerMode != mode { audioPlayer.nextPlayerMode() }
                }
            )) {
                Text("Off").tag(ArthubPlayer.PlayerMode.noRepeat)
                Text("Repeat All").tag(ArthubPlayer.PlayerMode.repeatPlaylist)
                Text("Repeat One").tag(ArthubPlayer.PlayerMode.repeatItem)
            }

            Divider()

            Button("Volume Up") {
                audioPlayer.volume = min(audioPlayer.volume + 0.1, 1)
            }
            .keyboardShortcut(.upArrow, modifiers: .command)

            Button("Volume Down") {
                audioPlayer.volume = max(audioPlayer.volume - 0.1, 0)
            }
            .keyboardShortcut(.downArrow, modifiers: .command)
        }
    }

    private func tabButton(_ tab: ContentView.AppTab, key: KeyEquivalent) -> some View {
        Button(tab.localizedName) {
            selectedTab?.wrappedValue = tab
        }
        .keyboardShortcut(key, modifiers: .command)
        .disabled(selectedTab == nil)
    }
}
