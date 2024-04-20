//
//  MusicViewModel.swift
//  Arthub
//
//  Created by 张鸿燊 on 18/3/2024.
//

import Foundation
import AVFoundation


@Observable class MusicViewModel {
    
    var musics: Set<MusicDetail> = []
    var fetchDataTask: Task<Void, Error>? = nil
    var isFetchingData = false
    var setupPlayerTask: Task<Void, Error>? = nil
    
    var currentMusic: MusicDetail? = nil
    var selectedMusicID: MusicDetail.ID? = nil
    var hoveringMusicID: MusicDetail.ID? = nil
    
    var selectedOrderProperty: MusicOrderProperty = .createdAt
    var selectedOrder: SortOrder = .forward
    var inspectorPresented: Bool = false
    var searchText: String = ""
    var playerPresented: Bool = false
    
    var sortComparator: KeyPathComparator<MusicDetail> {
        switch selectedOrderProperty {
        case .createdAt: KeyPathComparator(\.createdAt, order: selectedOrder)
        case .title: KeyPathComparator(\.title, order: selectedOrder)
        case .releaseDate: KeyPathComparator(\.releaseDate, order: selectedOrder)
        case .albumTitle: KeyPathComparator(\.album.title, order: selectedOrder)
        case .artistName:KeyPathComparator(\.artist.name, order: selectedOrder)
        }
    }

    var filteredMusics: [MusicDetail] {
        if searchText.isEmpty {
            return musics.sorted(using: sortComparator)
        }
        let search = searchText.lowercased()
        return musics.filter {
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
        isFetchingData = true
        fetchDataTask?.cancel()
        fetchDataTask = Task {
            let musics = try await withThrowingTaskGroup(of: Set<MusicDetail>.self) { group in
                var musics: Set<MusicDetail> = []
                group.addTask { try await self.fetchLocalData() }
                for try await result in group {
                    musics.formUnion(result)
                }
                return musics
            }

            DispatchQueue.main.async {
                // add new elements
                self.musics.formUnion(musics)
                // delete not exist element
                self.musics.formIntersection(musics)
                self.isFetchingData = false
            }
        }
    }
    
    func fetchLocalData() async throws -> Set<MusicDetail> {
        let urls = UserDefaults.standard.value(forKey: UserDefaults.localMusicData, default: [])
            .compactMap { URL(string: $0) }
        var musics: Set<MusicDetail> = []
        for musicDataURL in urls {
            let artistURLs = try FileManager.default
                .contentsOfDirectory(at: musicDataURL,
                                     includingPropertiesForKeys: [.isDirectoryKey],
                                     options: [.skipsHiddenFiles])
            for artistURL in artistURLs {
                let artist = ArtistDetail(name: artistURL.fileName.trimmingCharacters(in: .whitespaces))
                let albumURLs = try FileManager.default
                    .contentsOfDirectory(at: artistURL,
                                         includingPropertiesForKeys: [.isRegularFileKey],
                                         options: [.skipsHiddenFiles])
                for albumURL in albumURLs {
                    let albumTitle = albumURL.fileName
                    let album = AlbumDetail(title: albumTitle, artist: artist)
                    let urls = try FileManager.default
                        .contentsOfDirectory(at: albumURL,
                                             includingPropertiesForKeys: [.isRegularFileKey],
                                             options: [.skipsHiddenFiles])
                    for url in urls {
                        if url.isAudio, let matches = url.fileName.wholeMatch(of: RegexPattern.musicName) {
                            let trackNumber = Int(matches.output.trackNumber ?? "")
                            let discNumber = Int(matches.output.discNumber ?? "") ?? 1
                            let title = String(matches.output.title)
                            let ttmlURL = url.deletingPathExtension().deletingLastPathComponent()
                                .appending(component: title).appendingPathExtension(for: .ttml)
                            let lyrics = LyricsDetail()
                            if FileManager.default.fileExists(at: ttmlURL) {
                                lyrics.fileURL = ttmlURL
                            }
                            let music = MusicDetail(title: title, fileURL: url,
                                                    duration: try await AVURLAsset(url: url).load(.duration).seconds,
                                                    artist: artist, lyrics: lyrics, album: album,
                                                    trackNumber: trackNumber, discNumber: discNumber)
                            try await music.loadMetadata()
                            album.musics.append(music)
                            musics.insert(music)
                        }
                    }
                }
            }
        }
        return musics
    }
    
//    func fetchDirectoryData(_ url: URL) async throws -> Set<MusicDetail> {
//        guard url.hasDirectoryPath else { return [] }
//        let urls = try FileManager.default.contentsOfDirectory(at: url,
//                                                           includingPropertiesForKeys: nil,
//                                                           options: [.skipsHiddenFiles])
//        var musics: Set<MusicDetail> = []
//        for url in urls {
//            if url.hasDirectoryPath {
//                musics.formUnion(try await fetchDirectoryData(url))
//                continue
//            }
//        }
//        return musics
//    }
    
    
    func handlePlayItemIDChange(oldValue: Int?, newValue: Int?) {
        guard let id = newValue else {
            self.currentMusic = nil
            return
        }
        self.currentMusic = musics.first { $0.id.hashValue == id }
        guard let url = currentMusic?.lyrics.fileURL else {
            // search Musixmatch for lyrics
            return
        }
        self.currentMusic?.lyrics.body = Lyric.loadLyrics(url: url)
    }
}
