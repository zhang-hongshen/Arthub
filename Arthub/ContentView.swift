//
//  ContentView.swift
//  shelf
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
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @StateObject private var arthubPlayer: ArthubPlayer = ArthubPlayer()
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
        } detail: {
            if let mediaType = selectedMediaType {
                Group {
                    switch mediaType {
                    case .movie:
                        MovieView(columnVisibility: $columnVisibility)
                    case .music:
                        MusicView(columnVisibility: $columnVisibility)
                    }
                }
                .environmentObject(arthubPlayer)
            }
        }
    }
}

extension ContentView {
    @ViewBuilder
    func SidebarView() -> some View {
        List(selection: $selectedMediaType) {
            Text("Arthub")
                .font(.largeTitle)
                .fontWeight(.bold)
            Group {
                Label("sidebar.movie", systemImage: "film").tag(MediaType.movie)
                Label("sidebar.music", systemImage: "music.note").tag(MediaType.music)
            }
            .font(.title2)
        }
    }
}

#Preview {
    ContentView()
}
