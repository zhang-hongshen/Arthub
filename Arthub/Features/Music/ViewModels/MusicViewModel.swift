//
//  MusicViewModel.swift
//  Arthub
//
//  Created by 张鸿燊 on 18/3/2024.
//

import Foundation
import AVFoundation


@Observable class MusicViewModel {
    
    var songs: Set<Song> = []
    var fetchDataTask: Task<Void, Error>? = nil
    var isFetchingData = false
    var setupPlayerTask: Task<Void, Error>? = nil
    
    var currentSong: Song? = nil
    var selectedSongID: Song.ID? = nil
    var hoveringSongID: Song.ID? = nil
    
    var selectedOrderProperty: MusicOrderProperty = .createdAt
    var selectedOrder: SortOrder = .forward
    var inspectorPresented: Bool = false
    var searchText: String = ""
    var playerPresented: Bool = false
    
    var sortComparator: KeyPathComparator<Song> {
        switch selectedOrderProperty {
        case .createdAt: KeyPathComparator(\.createdAt, order: selectedOrder)
        case .title: KeyPathComparator(\.title, order: selectedOrder)
        case .releaseDate: KeyPathComparator(\.releaseDate, order: selectedOrder)
        case .albumTitle: KeyPathComparator(\.album.title, order: selectedOrder)
        case .artistName:KeyPathComparator(\.artist.name, order: selectedOrder)
        }
    }

    var filteredSongs: [Song] {
        if searchText.isEmpty {
            return songs.sorted(using: sortComparator)
        }
        let search = searchText.lowercased()
        return songs.filter {
            $0.title.lowercased().contains(search) ||
            $0.artist.name.lowercased().contains(search) ||
            $0.album.title.lowercased().contains(search) ||
            $0.album.artist.name.lowercased().contains(search)
        }
        .sorted(using: sortComparator)
    }
    
    deinit {
        fetchDataTask?.cancel()
        setupPlayerTask?.cancel()
    }
    
    func fetchData() {
        if let fetchDataTask = fetchDataTask {
            fetchDataTask.cancel()
        }
        isFetchingData = true
        fetchDataTask = Task {
            let songs = try await self.fetchLocalData()
            DispatchQueue.main.async {
                self.songs = songs
                self.isFetchingData = false
            }
        }
    }
    
    func fetchLocalData() async throws -> Set<Song> {
        let urls = UserDefaults.standard.value(forKey: UserDefaults.library, default: [])
            .compactMap { URL(string: $0) }
        if urls.isEmpty { return [] }
        return try await withThrowingTaskGroup(of: Set<Song>.self) { group in
            var songs: Set<Song> = []
            for url in urls {
                group.addTask{ try await self.fetchDirectoryData(url) }
            }
            for try await result in group {
                songs.formUnion(result)
            }
            return songs
        }
    }
    
    private func fetchDirectoryData(_ dir: URL) async throws -> Set<Song> {
        var songs: Set<Song> = []
        let urls = try FileManager.default
            .contentsOfDirectory(at: dir,
                                 includingPropertiesForKeys: [.isDirectoryKey],
                                 options: [.skipsHiddenFiles])
        for url in urls {
            if !url.hasDirectoryPath {
                songs.insert(try await handleSingleSong(url))
                continue
            }
            let artist = try await handleArtistDirectory(url)
            songs.formUnion(artist.albums.flatMap { $0.songs })
        }
        return songs
    }
    
    private func handleSingleSong(_ url: URL) async throws -> Song {
        return Song(title: url.fileName, fileURL: url,
                    duration: try await AVURLAsset(url: url).load(.duration).seconds)
    }
    
    private func handleArtistDirectory(_ dir: URL) async throws -> Artist {
        let artist = Artist(name: dir.fileName.trimmingCharacters(in: .whitespaces))
        let urls = try FileManager.default
            .contentsOfDirectory(at: dir,
                                 includingPropertiesForKeys: [.isRegularFileKey],
                                 options: [.skipsHiddenFiles])
        for url in urls {
            if !url.hasDirectoryPath {
                continue
            }
            let album = try await handleAlbumDirectory(url)
            album.artist = artist
            artist.albums.append(album)
        }
        return artist
    }
    
    private func handleAlbumDirectory(_ dir: URL) async throws-> Album {
        let album = Album(title: dir.fileName)
        let urls = try FileManager.default
            .contentsOfDirectory(at: dir,
                                 includingPropertiesForKeys: [.isRegularFileKey],
                                 options: [.skipsHiddenFiles])
        for url in urls {
            if url.isAudio, let matches = url.fileName.wholeMatch(of: RegexPattern.songName) {
                let trackNumber = Int(matches.output.trackNumber ?? "")
                let discNumber = Int(matches.output.discNumber ?? "") ?? 1
                let title = String(matches.output.title)
                let ttmlURL = url.deletingPathExtension().deletingLastPathComponent()
                    .appending(component: title).appendingPathExtension(for: .ttml)
                let lyrics = LyricsDetail()
                if FileManager.default.fileExists(at: ttmlURL) {
                    lyrics.fileURL = ttmlURL
                }
                let song = Song(title: title, fileURL: url,
                                duration: try await AVURLAsset(url: url).load(.duration).seconds,
                                lyrics: lyrics, album: album,
                                trackNumber: trackNumber, discNumber: discNumber)
                try await song.loadMetadata()
                album.songs.append(song)
            }
        }
        return album
    }
    
    
    func handlePlayItemIDChange(oldValue: Int?, newValue: Int?) {
        guard let id = newValue else {
            self.currentSong = nil
            return
        }
        self.currentSong = songs.first { $0.id.hashValue == id }
        guard let url = currentSong?.lyrics.fileURL else {
            // search Musixmatch for lyrics
            return
        }
        self.currentSong?.lyrics.body = Lyric.loadLyrics(url: url)
    }
}
