//
//  ContentView.swift
//  Arthub
//
//  Created by 张鸿燊 on 31/1/2024.
//

import SwiftUI
import SwiftData


enum MediaType {
    case movie, music
}

struct ContentView: View {
    
    @State private var selectedMediaType: MediaType? = nil
    @State private var state =  WindowState()
    @StateObject private var videoPlayer = ArthubVideoPlayer()
    @StateObject private var audioPlayer = ArthubAudioPlayer()
    
    var body: some View {
        NavigationSplitView(columnVisibility: Binding(
            get: { state.columnVisibility },
            set: { state.setColumnVisibility($0) })) {
            SidebarView()
        } detail: {
            if let mediaType = selectedMediaType {
                NavigationStack {
                    switch mediaType {
                    case .movie:
                        MovieView()
                    case .music:
                        MusicView()
                    }
                }
                
            }
        }
        .environment(state)
        .environmentObject(videoPlayer)
        .environmentObject(audioPlayer)
        .animation(.easeInOut, value: state.columnVisibility)
    }
}

extension ContentView {
    @ViewBuilder
    func SidebarView() -> some View {
        List(selection: $selectedMediaType) {
            Text(verbatim: "Arthub")
                .font(.largeTitle)
                .fontWeight(.semibold)
            
            Group {
                Label("sidebar.movie", systemImage: "film").tag(MediaType.movie)
                Label("sidebar.music", systemImage: "music.note").tag(MediaType.music)
                    .disabled(true)
            }
            .font(.title3)
        }
    }
}

#Preview {
    ContentView()
}
