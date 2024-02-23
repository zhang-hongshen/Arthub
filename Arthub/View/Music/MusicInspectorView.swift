//
//  MusicInspectorView.swift
//  Arthub
//
//  Created by 张鸿燊 on 1/2/2024.
//

import SwiftUI
import AVKit

enum MusicInspectorTab: String, CaseIterable, Identifiable {
    case info, lyrics
    var id: Self { self }
}

struct MusicInspectorView: View {
    
    @Binding var music: Music
    
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: MusicInspectorTab = .info
    @State private var lyrics: [Lyric] = []
    
    var body: some View {
        AutoWidthTabView(selection: $selectedTab) {
            InfoView().tag(MusicInspectorTab.info)
                .tabItem {
                    Text("music.detail")
                }
            LyricsEditView(lyrics: $lyrics).tag(MusicInspectorTab.lyrics)
                .tabItem {
                    Text("music.lyrics")
                }
        }
        .task {
            guard let url = music.lyrics else {
                return
            }
            self.lyrics = Lyric.loadLyrics(url: url)
        }
    }
}

extension MusicInspectorView {
    
    @ViewBuilder
    func InfoView() -> some View {
        VStack {
            AsyncImage(url: music.album?.cover,
                       transaction: .init(animation: .smooth)
            ) { phase in
                switch phase {
                case .empty:
                    DefaultImageView()
                case .success(let image):
                    image.resizable().scaledToFit()
                case .failure(let error):
                    ErrorImageView(error: error)
                @unknown default:
                    fatalError()
                }
            }
            .cornerRadius()
            
            
            Grid(alignment: .leadingFirstTextBaseline) {
                
                GridRow {
                    Text("music.title").gridColumnAlignment(.trailing)
                    TextField("", text: $music.title)
                        .cornerRadius()
                }

                GridRow {
                    Text("music.artists").gridColumnAlignment(.trailing)
                    VStack(alignment: .leading) {
                        ForEach($music.artists) { artist in
                            TextField("", text: artist.name)
                                .cornerRadius()
                        }
                    }
                }
                
                GridRow {
                    Text("music.composers").gridColumnAlignment(.trailing)
                    VStack(alignment: .leading) {
                        ForEach($music.composers) { composer in
                            TextField("", text: composer)
                                .cornerRadius()
                        }
                    }
                }
                
                GridRow {
                    Text("music.lyricists").gridColumnAlignment(.trailing)
                    VStack(alignment: .leading) {
                        ForEach($music.lyricists) { lyricist in
                            TextField("", text: lyricist)
                                .cornerRadius()
                        }
                    }
                }
                
                GridRow {
                    Text("album.title").gridColumnAlignment(.trailing)
                    TextField("", text: Binding(
                                get: { music.album?.title ?? ""},
                                set: { _ in }))
                        .cornerRadius()
                }
                
                GridRow {
                    Text("album.artists").gridColumnAlignment(.trailing)
                    VStack(alignment: .leading) {
                        ForEach(Binding(
                            get: { music.album?.artists ?? []},
                            set: { _ in })) { artist in
                            TextField("", text: artist.name)
                                .cornerRadius()
                        }
                    }
                }
            }
        }
        .font(.title2)
    }
}
