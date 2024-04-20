//
//  MusicDetail.swift
//  Arthub
//
//  Created by 张鸿燊 on 1/2/2024.
//

import Foundation
import AVFoundation
//import SwiftUI

@Observable
class MusicDetail: MediaItem,Identifiable, Hashable {
    let id = UUID()
    let createdAt: Date = Date.now
    var modifiedAt: Date = Date.now
    
    var title: String
    var artist: ArtistDetail
    var composer: String
    var lyricist: String
    var arranger: String
    var releaseDate: Date?
    
    var lyrics: LyricsDetail
    var album: AlbumDetail
    var discNumber: Int?
    var trackNumber: Int?
    
    init(title: String = "" , fileURL: URL, duration: TimeInterval,
         artist: ArtistDetail = ArtistDetail(), composer: String = "", lyricist: String = "",
         arranger: String = "", releaseDate: Date? = nil, lyrics: LyricsDetail = LyricsDetail(),
         album: AlbumDetail = AlbumDetail(), trackNumber: Int? = nil, discNumber: Int? = nil) {
        self.title = title
        self.artist = artist
        self.composer = composer
        self.lyricist = lyricist
        self.arranger = arranger
        self.releaseDate = releaseDate
        self.lyrics =  lyrics
        self.album = album
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        super.init(fileURL: fileURL, duration: duration)
    }
    
    static func == (lhs: MusicDetail, rhs: MusicDetail) -> Bool {
        return lhs.title == rhs.title
        && lhs.artist == rhs.artist
        && lhs.album == rhs.album
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(artist)
        hasher.combine(album)
    }
}

extension MusicDetail {
    
    func loadMetadata() async throws {
        try await loadLocalMetadata()
    }
    
    private func loadLocalMetadata() async throws {
        let asset = AVAsset(url: fileURL)
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            
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
    
}

extension MusicDetail {
    
    private func commonMetadata(_ metadata: [AVMetadataItem]) async throws {
        if artist.name.isEmpty {
            if let artworkItem = AVMetadataItem.metadataItems(from: metadata,
                                                              filteredByIdentifier: .commonIdentifierArtist).first,
               let artist = try await artworkItem.load(.stringValue) {
                self.artist.name = artist
            }
        }
        if album.title.isEmpty {
            if let artworkItem = AVMetadataItem.metadataItems(from: metadata,
                                                              filteredByIdentifier: .commonIdentifierAlbumName).first,
               let albumTitle = try await artworkItem.load(.stringValue) {
                self.album.title = albumTitle
            }
        }
        if album.cover == nil {
            let artworkItems = AVMetadataItem.metadataItems(
                from: metadata, filteredByIdentifier: .commonIdentifierArtwork)
            for artworkItem in artworkItems {
                if let artwork = try await artworkItem.load(.dataValue) {
                    self.album.cover = artwork
                }
            }
        }
    }
    private func id3Metadata(_ metadata: [AVMetadataItem]) async throws {
        
        if artist.name.isEmpty {
            if let artworkItem = AVMetadataItem.metadataItems(from: metadata,
                                                              filteredByIdentifier: .id3MetadataLeadPerformer).first,
               let artist = try await artworkItem.load(.stringValue) {
                self.artist.name = artist
            }
        }
        
        if composer.isEmpty {
            let artworkItems = AVMetadataItem.metadataItems(
                from: metadata, filteredByIdentifier: .id3MetadataComposer)
            for artworkItem in artworkItems {
                if let composer = try await artworkItem.load(.stringValue) {
                    self.composer = composer
                }
            }
        }
        if lyricist.isEmpty {
            let artworkItems = AVMetadataItem.metadataItems(
                from: metadata, filteredByIdentifier: .id3MetadataLyricist)
            for artworkItem in artworkItems {
                if let lyricist = try await artworkItem.load(.stringValue) {
                    self.lyricist = lyricist
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
        
        if album.title.isEmpty {
            if let artworkItem = AVMetadataItem.metadataItems(from: metadata,
                                                              filteredByIdentifier: .id3MetadataAlbumTitle).first,
               let albumTitle = try await artworkItem.load(.stringValue) {
                self.album.title = albumTitle
            }
        }
        if lyrics.body.isEmpty {
            if let artworkItem = AVMetadataItem.metadataItems(from: metadata,
                                                              filteredByIdentifier: .id3MetadataSynchronizedLyric).first,
               let lyrics = try await artworkItem.load(.dataValue) {
                self.lyrics.body = TTMLParser().parse(data: lyrics)
            }
        }
        if trackNumber == nil {
            if let artworkItem = AVMetadataItem.metadataItems(from: metadata,
                                                              filteredByIdentifier: .id3MetadataTrackNumber).first,
               let trackNumber = try await artworkItem.load(.numberValue) {
                self.trackNumber = trackNumber.intValue
            }
        }
    }
    
    private func iTunesMetadata(_ metadata: [AVMetadataItem]) async throws {
        if artist.name.isEmpty {
            if let artworkItem = AVMetadataItem.metadataItems(
                from: metadata, filteredByIdentifier: .iTunesMetadataPerformer).first,
               let artistName = try await artworkItem.load(.stringValue) {
                self.artist.name = artistName
            }
        }
        if album.title.isEmpty {
            if let artworkItem = AVMetadataItem.metadataItems(
                from: metadata, filteredByIdentifier: .iTunesMetadataAlbum).first,
               let albumTitle = try await artworkItem.load(.stringValue) {
                self.album.title = albumTitle
            }
        }
        if album.cover == nil {
            if let artworkItem = AVMetadataItem.metadataItems(
                from: metadata, filteredByIdentifier: .iTunesMetadataCoverArt).first,
               let cover = try await artworkItem.load(.dataValue) {
                self.album.cover = cover
            }
        }
        
        if album.artist.name.isEmpty {
            if let artworkItem = AVMetadataItem.metadataItems(
                from: metadata, filteredByIdentifier: .iTunesMetadataAlbumArtist).first,
               let albumArtistName = try await artworkItem.load(.stringValue) {
                self.album.artist.name = albumArtistName
            }
        }
        
        if composer.isEmpty {
            if let artworkItem = AVMetadataItem.metadataItems(
                from: metadata, filteredByIdentifier: .iTunesMetadataComposer).first,
               let composer = try await artworkItem.load(.stringValue) {
                self.composer = composer
            }
        }
        if arranger.isEmpty {
            if let artworkItem = AVMetadataItem.metadataItems(
                from: metadata, filteredByIdentifier: .iTunesMetadataArranger).first,
               let arranger = try await artworkItem.load(.stringValue) {
                self.arranger = arranger
            }
        }
        if trackNumber == nil {
            if let artworkItem = AVMetadataItem.metadataItems(
                from: metadata, filteredByIdentifier: .iTunesMetadataTrackNumber).first,
                let trackNumber = try await artworkItem.load(.numberValue) {
                self.trackNumber = trackNumber.intValue
            }
        }
        if discNumber == nil {
            if let artworkItem = AVMetadataItem.metadataItems(
                from: metadata, filteredByIdentifier: .iTunesMetadataDiscNumber).first,
               let discNumber = try await artworkItem.load(.numberValue) {
                self.discNumber = discNumber.intValue
            }
        }
        if lyrics.body.isEmpty {
            if let artworkItem = AVMetadataItem.metadataItems(
                from: metadata, filteredByIdentifier: .iTunesMetadataLyrics).first,
               let lyrics = try await artworkItem.load(.dataValue) {
                self.lyrics.body = TTMLParser().parse(data: lyrics)
            }
        }
    }
}
