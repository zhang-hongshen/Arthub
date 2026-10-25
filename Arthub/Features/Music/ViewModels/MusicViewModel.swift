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

    /// Albums grouped under the album artist, for browsing by artist.
    struct ArtistAlbums: Identifiable {
        var id: String { name }
        let name: String
        let albums: [Album]
    }

    var songs: Set<Song> = []
    var isFetchingData = false
    var scanErrors: [String] = []
    @ObservationIgnored var setupPlayerTask: Task<Void, Error>? = nil

    var currentSong: Song? = nil
    var selectedSongID: Song.ID? = nil

    var viewMode: MusicViewMode = .songs
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

    /// Albums of the matching songs, in the order their songs sort, except by title, which sorts album titles.
    var filteredAlbums: [Album] {
        var seen: Set<ObjectIdentifier> = []
        let albums = filteredSongs.map(\.album).filter { seen.insert(ObjectIdentifier($0)).inserted }
        guard selectedOrderProperty == .title else { return albums }
        return albums.sorted {
            $0.title.localizedStandardCompare($1.title) == (selectedOrder == .forward ? .orderedAscending : .orderedDescending)
        }
    }

    var filteredArtists: [ArtistAlbums] {
        let grouped = Dictionary(grouping: filteredAlbums) { album in
            album.artist.name.isEmpty ? (album.songs.first?.artist.name ?? "") : album.artist.name
        }
        let ascending = selectedOrderProperty != .artistName || selectedOrder == .forward
        return grouped.map { ArtistAlbums(name: $0.key, albums: $0.value) }
            .sorted { $0.name.localizedStandardCompare($1.name) == (ascending ? .orderedAscending : .orderedDescending) }
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
                // A song whose tags changed, such as after saving them, stays the same song, so it stays
                // selected and playing.
                let existing = indexedSongs[file.id]
                let song = existing ?? Song(fileURL: file.fileURL, duration: file.duration)
                song.fileURL = file.fileURL
                song.duration = file.duration
                if existing == nil || indexedMetadata[file.id] != metadata {
                    song.title = metadata?.title ?? file.fileURL.fileName
                    song.artist = Artist(name: metadata?.artist ?? "")
                    song.composer = metadata?.composer ?? ""
                    song.lyricist = metadata?.lyricist ?? ""
                    song.arranger = metadata?.arranger ?? ""
                    song.releaseDate = metadata?.releaseDate
                    song.album = Album(title: metadata?.album ?? "", artist: Artist(name: metadata?.albumArtist ?? ""),
                                       releaseDate: metadata?.releaseDate, cover: metadata?.cover)
                    song.trackNumber = metadata?.trackNumber
                    song.discNumber = metadata?.discNumber
                    // A lyrics file is shown before embedded lyrics, and loads when the song plays.
                    if !song.lyrics.isUnsaved, song.lyrics.fileURL == nil {
                        song.lyrics.body = metadata?.lyrics.map(\.lyric) ?? []
                    }
                    song.unsavedTags = []
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

    /// The song shown for a library file, so music started elsewhere plays the same song objects.
    func song(forFileID id: UUID) -> Song? { indexedSongs[id] }

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
        guard let song = currentSong else { return }
        guard let url = song.lyrics.fileURL else {
            // A song without lyrics of its own is looked up online, again only after a failure.
            if song.lyrics.body.isEmpty, song.lyrics.lookup == nil || song.lyrics.lookup == .failed {
                Task { await song.searchLyrics() }
            }
            return
        }
        // Unsaved changes stay until they're saved.
        guard !song.lyrics.isUnsaved else { return }
        song.lyrics.body = Lyric.loadLyrics(url: url)
    }
}
