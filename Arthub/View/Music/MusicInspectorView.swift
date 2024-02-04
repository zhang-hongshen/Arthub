//
//  MusicInspectorView.swift
//  Shelf
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
    
    @Bindable var music: Music
    
    @State private var selectedTab: MusicInspectorTab = .info
    
    var asset: AVAsset
    
    init(music: Music) {
        self.music = music
        asset = AVAsset(url: Bundle.main.url(forResource: music.filepath, withExtension: "mp3")!)
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            InfoView().tag(MusicInspectorTab.info)
                .tabItem {
                    Text("inspector.tab.info")
                }
                .task {
                    await mixMetadata()
                }
            LyricsView().tag(MusicInspectorTab.lyrics)
                .tabItem {
                    Text("inspector.tab.lyrics")
                }
        }
        .padding(10)
    }
}

extension MusicInspectorView {
    
    func mixMetadata() async {
        
        do {
            
            let metadata = try await asset.loadMetadata(for: .id3Metadata)
            if music.name.isEmpty {
                if let artworkItem = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .commonIdentifierTitle).first,
                    let name = try await artworkItem.load(.stringValue) {
                    music.name = name
                }
            }
            if music.artist.isEmpty {
                if let artworkItem = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .commonIdentifierArtist).first,
                    let artist = try await artworkItem.load(.stringValue) {
                    music.artist = artist
                }
            }
            if music.album == nil {
                if let artworkItem = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .commonIdentifierAlbumName).first, 
                    let albumName = try await artworkItem.load(.stringValue) {
                    music.album = Album(name: albumName, artist: music.artist)
                }
            }
        } catch {
            debugPrint("\(error)")
        }
    }
}

extension MusicInspectorView {
    
    @ViewBuilder
    func InfoView() -> some View {
        VStack {
            Image(music.thumbnail)
                .resizable()
                .scaledToFit()
                .rounded()
            
            Grid(alignment: .leadingFirstTextBaseline) {
                
                GridRow {
                    Text("music.name").gridColumnAlignment(.trailing)
                    TextField("music.name", text: $music.name)
                        .fixedSize()
                        .rounded()
                        .onSubmit {
                            debugPrint("submit name")
                        }
                }
                GridRow {
                    Text("music.artist").gridColumnAlignment(.trailing)
                    TextField("music.artist", text: $music.artist)
                        .fixedSize()
                        .rounded()
                }
                GridRow {
                    Text("music.albumName").gridColumnAlignment(.trailing)
                    TextField("music.albumName", text: Binding<String> {
                            guard let album = music.album else {
                                return ""
                            }
                            return album.name
                        } set: { newValue in
                            if let album = music.album {
                                album.name = newValue
                            } else {
                                music.album = Album(name: newValue, artist: music.artist)
                            }
                    })
                    .fixedSize()
                    .rounded()
                }
                GridRow {
                    Text("music.albumArtist").gridColumnAlignment(.trailing)
                    TextField("music.albumArtist", text: Binding<String> {
                        guard let album = music.album else {
                            return ""
                        }
                        return album.artist
                    } set: { newValue in
                        if let album = music.album {
                            album.artist = newValue
                        } else {
                            music.album = Album(name: "", artist: newValue)
                        }
                    })
                    .fixedSize()
                    .rounded()
                }
                GridRow {
                    Text("music.releaseYear").gridColumnAlignment(.trailing)
                    TextField("music.releaseYear", text: $music.releaseYear)
                        .fixedSize()
                        .rounded()
                }
            }
        }
        
        
        .font(.title2)
    }
}

extension MusicInspectorView {
    
    @ViewBuilder
    func LyricsView() -> some View {
        TextEditor(text: $music.lyrics)
            .font(.title3)
            .onChange(of: music.lyrics, initial: false) {
                print("lyrics change")
            }
    }
}

#Preview {
    MusicInspectorView(music: Music.examples()[0])
}
