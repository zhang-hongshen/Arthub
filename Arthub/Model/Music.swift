//
//  Music.swift
//  Shelf
//
//  Created by 张鸿燊 on 1/2/2024.
//

import Foundation
import SwiftUI
import AVFoundation

class Music: Identifiable {
    let id = UUID()
    let createdAt: Date = Date.now
    var modifiedAt: Date = Date.now
    
    var title: String
    var url: URL
    var artists: [Artist]
    var composers: [String]
    var lyricists: [String]
    var releaseDate: Date?
    
    var lyrics: URL?
    var album: Album?
    var order: Int?
    
    init(title: String = "" , url: URL,
         artists: [Artist] = [], composers: [String] = [],
         lyricists: [String] = [], releaseDate: Date? = nil,
         lyrics: URL? = nil, album: Album? = nil, order: Int? = nil) {
        self.title = title
        self.url = url
        self.artists = artists
        self.composers = composers
        self.lyricists = lyricists
        self.releaseDate = releaseDate
        self.lyrics =  lyrics
        self.album = album
        self.order = 0
    }
    
    func getArtists() -> [Artist] {
        if !artists.isEmpty {
            return artists
        }
        return album?.artists ?? []
    }
}

extension Music: Equatable {
    static func == (lhs: Music, rhs: Music) -> Bool {
        return lhs.id == rhs.id
    }
}

enum MusicOrderProperty: String, CaseIterable, Identifiable {
    case title, createdAt, releaseDate
    var id: Self { self }
}

enum MusicGroup: String, CaseIterable, Identifiable {
    case none, releaseYear
    var id: Self { self }
}

extension Music {
    
    func loadMetadata() async throws {
        @AppStorage(UserDefaults.musicMetadata)
        var musicMetadata: MusicMetadata = MusicMetadata.local

        switch musicMetadata {
        case .local:
            try await loadLocalMetadata()
        case .musicbrainz:
            try await loadMusicBrainzMetadata()
        }
    }
    
    private func loadLocalMetadata() async throws {
        let asset = AVAsset(url: url)
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                let commonMetadata = try await asset.load(.commonMetadata)
                try await self.loadCommonMetadata(commonMetadata)
            }
            
            group.addTask {
                let id3Metadata = try await asset.loadMetadata(for: .id3Metadata)
                try await self.loadID3Metadata(id3Metadata)
            }
        }
    }
    
    private func loadMusicBrainzMetadata() async throws {
        
    }
}

extension Music {
    
    private func loadCommonMetadata(_ metadata: [AVMetadataItem]) async throws {
        if title.isEmpty {
            if let artworkItem = AVMetadataItem.metadataItems(
                from: metadata, filteredByIdentifier: .commonIdentifierTitle).first,
                let title = try await artworkItem.load(.stringValue) {
                self.title = title
            }
        }
        if artists.isEmpty {
            if let artworkItem = AVMetadataItem.metadataItems(
                from: metadata, filteredByIdentifier: .commonIdentifierArtist).first,
                let artist = try await artworkItem.load(.stringValue) {
                self.artists.append(Artist(name: artist))
            }
        }
    }
    
    private func loadID3Metadata(_ metadata: [AVMetadataItem]) async throws {
        if title.isEmpty {
            if let artworkItem = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .id3MetadataTitleDescription).first,
                let title = try await artworkItem.load(.stringValue) {
                self.title = title
            }
        }
        if artists.isEmpty {
            if let artworkItem = AVMetadataItem.metadataItems(
                from: metadata, filteredByIdentifier: .id3MetadataOriginalArtist).first,
                let artist = try await artworkItem.load(.stringValue) {
                self.artists.append(Artist(name: artist))
            }
        }
        if composers.isEmpty {
            let artworkItems = AVMetadataItem.metadataItems(
                from: metadata, filteredByIdentifier: .id3MetadataComposer)
            for artworkItem in artworkItems {
                if let composer = try await artworkItem.load(.stringValue) {
                    self.composers.append(composer)
                }
            }
        }
        if lyricists.isEmpty {
            let artworkItems = AVMetadataItem.metadataItems(
                from: metadata, filteredByIdentifier: .id3MetadataLyricist)
            for artworkItem in artworkItems {
                if let lyricist = try await artworkItem.load(.stringValue) {
                    self.lyricists.append(lyricist)
                }
            }
        }
        if self.releaseDate == nil {
            if let artworkItem = AVMetadataItem.metadataItems(from: metadata,
                                                              filteredByIdentifier: .id3MetadataReleaseTime).first,
               let releaseDate = try await artworkItem.load(.dateValue) {
                self.releaseDate = releaseDate
            }
        }
    }
}
