//
//  Music.swift
//  Shelf
//
//  Created by 张鸿燊 on 1/2/2024.
//

import Foundation
import SwiftUI
import AVFoundation

enum MusicOrderProperty: String, CaseIterable, Identifiable {
    case title, createdAt, releaseDate
    var id: Self { self }
}

enum MusicGroup: String, CaseIterable, Identifiable {
    case none, releaseYear
    var id: Self { self }
}

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
    var discNum: Int?
    var trackNum: Int?
    
    init(title: String = "" , url: URL, artists: [Artist] = [],
         composers: [String] = [], lyricists: [String] = [],
         releaseDate: Date? = nil, lyrics: URL? = nil, album: Album? = nil,
         trackNum: Int? = nil, discNum: Int? = nil) {
        self.title = title
        self.url = url
        self.artists = artists
        self.composers = composers
        self.lyricists = lyricists
        self.releaseDate = releaseDate
        self.lyrics =  lyrics
        self.album = album
        self.trackNum = trackNum
        self.discNum = discNum
    }
}

extension Music: Equatable {
    static func == (lhs: Music, rhs: Music) -> Bool {
        return lhs.id == rhs.id
    }
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
                try await self.commonMetadata(commonMetadata)
            }
            
            group.addTask {
                let id3Metadata = try await asset.loadMetadata(for: .id3Metadata)
                try await self.id3Metadata(id3Metadata)
            }
            
            group.addTask {
                let iTunesMetadata = try await asset.loadMetadata(for: .iTunesMetadata)
                try await self.iTunesMetadata(iTunesMetadata)
            }
            try await group.waitForAll()
        }
    }
    
    private func loadMusicBrainzMetadata() async throws {
        
    }
}

extension Music {
    
    private func commonMetadata(_ metadata: [AVMetadataItem]) async throws {
        if artists.isEmpty {
            if let artworkItem = AVMetadataItem.metadataItems(
                from: metadata, filteredByIdentifier: .commonIdentifierArtist).first,
                let artist = try await artworkItem.load(.stringValue) {
                self.artists.append(Artist(name: artist))
            }
        }
    }
    
    private func id3Metadata(_ metadata: [AVMetadataItem]) async throws {
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
        if releaseDate == nil {
            if let artworkItem = AVMetadataItem.metadataItems(from: metadata,
                                                              filteredByIdentifier: .id3MetadataReleaseTime).first,
               let releaseDate = try await artworkItem.load(.dateValue) {
                self.releaseDate = releaseDate
            }
        }
    }
    
    private func iTunesMetadata(_ metadata: [AVMetadataItem]) async throws {
        
        if artists.isEmpty{
            if let artworkItem = AVMetadataItem.metadataItems(
                from: metadata, filteredByIdentifier: .iTunesMetadataArtist).first,
                let artist = try await artworkItem.load(.stringValue) {
                self.artists.append(Artist(name: artist))
            }
        }
        if trackNum == nil {
            if let artworkItem = AVMetadataItem.metadataItems(
                from: metadata, filteredByIdentifier: .iTunesMetadataTrackNumber).first,
                let trackNum = try await artworkItem.load(.numberValue) {
                self.trackNum = trackNum.intValue
            }
        }
        if discNum == nil {
            if let artworkItem = AVMetadataItem.metadataItems(
                from: metadata, filteredByIdentifier: .iTunesMetadataDiscNumber).first,
               let discNum = try await artworkItem.load(.numberValue) {
                self.discNum = discNum.intValue
            }
        }
    }
}
