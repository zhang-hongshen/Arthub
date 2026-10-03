//
//  MusicViewModel.swift
//  Arthub
//
//  Created by 张鸿燊 on 18/3/2024.
//

import Foundation
import AVFoundation


@MainActor @Observable class MusicViewModel {

    enum InspectorContent { case info, lyrics }

    var songs: Set<Song> = []
    var isFetchingData = false
    var scanErrors: [String] = []
    @ObservationIgnored var setupPlayerTask: Task<Void, Error>? = nil

    var currentSong: Song? = nil
    var selectedSongID: Song.ID? = nil

    var selectedOrderProperty: MusicOrderProperty = .createdAt
    var selectedOrder: SortOrder = .forward
    var inspectorPresented: Bool = false
    var inspectorContent: InspectorContent = .info
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

    @ObservationIgnored private var indexedSongs: [UUID: Song] = [:]
    @ObservationIgnored private var indexedMetadata: [UUID: LibraryAudioMetadata] = [:]
    @ObservationIgnored private var fetchDataTask: Task<Void, Never>? = nil

    deinit {
        fetchDataTask?.cancel()
        setupPlayerTask?.cancel()
    }

    func fetchData() { fetchData(refreshLibrary: true) }

    func fetchData(refreshLibrary: Bool) {
        fetchDataTask?.cancel()
        isFetchingData = true
        fetchDataTask = Task {
            let library = LibraryViewModel.shared
            if refreshLibrary { await library.refresh() }
            guard !Task.isCancelled else { return }
            var result: [UUID: Song] = [:]
            var metadataByID: [UUID: LibraryAudioMetadata] = [:]
            for file in library.files where !file.fileURL.isVideo {
                let metadata = file.audio
                let song: Song
                if let existing = indexedSongs[file.id], indexedMetadata[file.id] == metadata {
                    song = existing
                    song.fileURL = file.fileURL
                    song.duration = file.duration
                } else {
                    let album = Album(title: metadata?.album ?? "",
                                      artist: Artist(name: metadata?.albumArtist ?? ""), cover: metadata?.cover)
                    song = Song(title: metadata?.title ?? file.fileURL.fileName, fileURL: file.fileURL,
                                duration: file.duration, artist: Artist(name: metadata?.artist ?? ""),
                                composer: metadata?.composer ?? "", lyricist: metadata?.lyricist ?? "",
                                arranger: metadata?.arranger ?? "", releaseDate: metadata?.releaseDate,
                                lyrics: LyricsDetail(body: metadata?.lyrics.map(\.lyric) ?? []), album: album, trackNumber: metadata?.trackNumber, discNumber: metadata?.discNumber)
                }
                song.isAvailable = file.isAvailable
                if file.isAvailable {
                    song.lyrics.fileURL = MediaNaming.lyrics(for: file.fileURL, title: song.title)
                }
                result[file.id] = song
                metadataByID[file.id] = metadata
            }
            // Retain album browsing while reusing unchanged tracks and their playback state.
            var albums: [String: Album] = [:]
            for song in result.values {
                let key = "\(song.album.artist.name)\u{0}\(song.album.title)"
                if let album = albums[key] { song.album = album }
                else { song.album.songs = []; albums[key] = song.album }
                song.album.songs.append(song)
            }
            indexedSongs = result
            indexedMetadata = metadataByID
            songs = Set(result.values)
            scanErrors = library.scanErrors
            isFetchingData = false
        }
    }

    var lyricsPresented: Bool { inspectorPresented && inspectorContent == .lyrics }

    /// Lyrics and Info share the inspector; tapping the active one closes it.
    func toggleInspector(_ content: InspectorContent) {
        if inspectorPresented && inspectorContent == content {
            inspectorPresented = false
        } else {
            inspectorContent = content
            inspectorPresented = true
        }
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
