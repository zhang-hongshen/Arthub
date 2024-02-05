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
    
    @Bindable var music: Music
    
    @State private var selectedTab: MusicInspectorTab = .info
    @Environment(\.modelContext) private var modelContext
    
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
            LyricsEditView(lyrics: $music.lyrics).tag(MusicInspectorTab.lyrics)
                .tabItem {
                    Text("inspector.tab.lyrics")
                }
        }
        .padding(10)
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
                                let album = Album(name: newValue, artist: "")
                                modelContext.insert(album)
                                music.album = album
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
                            let album = Album(name: "", artist: newValue)
                            modelContext.insert(album)
                            music.album = album
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
    
    func mixMetadata() async {
        
        do {
            try await tryID3Metadata()
            try await tryITunesMetadata()
        } catch {
            debugPrint("\(error)")
        }
    }
    
    func tryID3Metadata() async throws {
        let metadata = try await asset.loadMetadata(for: .id3Metadata)
        if music.name.isEmpty {
            if let artworkItem = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .id3MetadataTitleDescription).first,
                let name = try await artworkItem.load(.stringValue) {
                music.name = name
            }
        }
        if music.artist.isEmpty {
            if let artworkItem = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .id3MetadataOriginalArtist).first,
                let artist = try await artworkItem.load(.stringValue) {
                music.artist = artist
            }
        }
        if music.album == nil {
            let album = Album()
            if let artworkItem = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .id3MetadataAlbumTitle).first,
                let albumName = try await artworkItem.load(.stringValue) {
                album.name = albumName
            }
            music.album = album
        }
        if music.releaseYear.isEmpty {
            if let artworkItem = AVMetadataItem.metadataItems(from: metadata,
                                                              filteredByIdentifier: .id3MetadataReleaseTime).first,
               let releaseDate = try await artworkItem.load(.dateValue) {
                music.releaseYear = Calendar.current.component(.year, from: releaseDate).formatted()
            }
        }
    }
    
    
    func tryITunesMetadata() async throws {
        let metadata = try await asset.loadMetadata(for: .iTunesMetadata)
        if music.name.isEmpty {
            if let artworkItem = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .iTunesMetadataSongName).first,
                let name = try await artworkItem.load(.stringValue) {
                music.name = name
            }
        }
        if music.artist.isEmpty {
            if let artworkItem = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .iTunesMetadataArtist).first,
                let artist = try await artworkItem.load(.stringValue) {
                music.artist = artist
            }
        }
        if music.album == nil {
            let album = Album()
            if let artworkItem = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .iTunesMetadataAlbum).first,
                let albumName = try await artworkItem.load(.stringValue) {
                album.name = albumName
            }
            if let artworkItem = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .iTunesMetadataAlbumArtist).first,
                let albumArtist = try await artworkItem.load(.stringValue) {
                album.artist = albumArtist
            }

            music.album = album
        }
        if music.releaseYear.isEmpty {
            if let artworkItem = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .iTunesMetadataReleaseDate).first,
               let releaseDate = try await artworkItem.load(.dateValue) {
                //extract release year from release data
                music.releaseYear = Calendar.current.component(.year, from: releaseDate).formatted()
            }
        }
    }
}

#Preview {
    MusicInspectorView(music: Music.examples()[0])
        .modelContainer(for: Music.self, inMemory: true)
}
