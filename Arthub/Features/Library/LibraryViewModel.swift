import Foundation
import AVFoundation
import TMDb

struct LibraryFile: Codable, Identifiable {
    var id = UUID()
    var fileURL: URL
    var library: String
    var fileIdentity: String?
    var modifiedAt: Date?
    var size: Int = 0
    var addedAt = Date.now
    var isAvailable = true
    var duration: TimeInterval = 0
    var audio: LibraryAudioMetadata?
    var movie: TMDb.Movie?
    var series: TVSeries?
    var season: TVSeason?
    var episode: TVEpisode?
    /// Infuse-style image files next to the video, found on every scan.
    var localArtwork: MediaNaming.Artwork?
    var isManuallyMatched = false
    var didIdentify = false
    var namingVersion: Int?
    var error: String?

    var isMatched: Bool { movie != nil || episode != nil }
    var title: String { movie?.title ?? episode?.name ?? fileURL.lastPathComponent }
    var artwork: URL? {
        localArtwork?.poster ?? movie?.posterPath ?? localArtwork?.thumbnail ?? episode?.stillPath
    }

    /// Metadata with TMDb images replaced by local artwork where it exists.
    var movieWithArtwork: TMDb.Movie? {
        movie?.copy(posterPath: localArtwork?.poster, backdropPath: localArtwork?.backdrop)
    }
    var seriesWithArtwork: TVSeries? {
        series?.copy(posterPath: localArtwork?.poster, backdropPath: localArtwork?.backdrop)
    }
    var seasonWithArtwork: TVSeason? { season?.copy(posterPath: localArtwork?.seasonPoster) }
    var episodeWithArtwork: TVEpisode? { episode?.copy(stillPath: localArtwork?.thumbnail) }
}

@MainActor @Observable
final class LibraryViewModel {
    static let shared = LibraryViewModel()

    private(set) var files: [LibraryFile] = []
    private(set) var offlineLibraries: Set<String> = []
    private(set) var scanErrors: [String] = []
    private(set) var isScanning = false
    private(set) var isMatching = false
    private(set) var revision = 0
    var storageError: String?

    @ObservationIgnored private var loaded = false
    @ObservationIgnored private var canSave = true
    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private var resolvedFolders: [String: URL] = [:]
    @ObservationIgnored private var accessedURLs: [String: URL] = [:]
    private static let bookmarkKey = "libraryBookmarks"
    nonisolated private static let indexURL = URL.applicationSupportDirectory
        .appending(path: "Arthub/Library.json")

    func rememberFolder(_ url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        #if os(macOS)
        let options: URL.BookmarkCreationOptions = [.withSecurityScope, .securityScopeAllowOnlyReadAccess]
        #else
        let options: URL.BookmarkCreationOptions = [.minimalBookmark]
        #endif
        let bookmark = try url.bookmarkData(options: options, includingResourceValuesForKeys: nil,
                                            relativeTo: nil)
        var bookmarks = UserDefaults.standard.dictionary(forKey: Self.bookmarkKey) as? [String: Data] ?? [:]
        bookmarks[url.absoluteString] = bookmark
        UserDefaults.standard.set(bookmarks, forKey: Self.bookmarkKey)
    }

    func refresh() async {
        if let scanTask { await scanTask.value; return }
        guard !isMatching else { return }
        let task = Task { await self.scan() }
        scanTask = task
        await task.value
        scanTask = nil
    }

    private func scan() async {
        isScanning = true
        defer { isScanning = false }
        if !loaded {
            do {
                files = try await Task.detached {
                    guard FileManager.default.fileExists(atPath: Self.indexURL.path) else { return [LibraryFile]() }
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .custom { decoder in
                        let value = try decoder.singleValueContainer().decode(String.self)
                        guard let seconds = Double(value) else { throw CocoaError(.fileReadCorruptFile) }
                        return Date(timeIntervalSinceReferenceDate: seconds)
                    }
                    return try decoder.decode([LibraryFile].self, from: Data(contentsOf: Self.indexURL))
                }.value
            } catch {
                canSave = false
                storageError = error.localizedDescription
            }
            // Files identified under older naming rules are matched again once.
            for index in files.indices where files[index].namingVersion != MediaNaming.version {
                files[index].namingVersion = MediaNaming.version
                files[index].didIdentify = false
                if !files[index].isManuallyMatched {
                    files[index].movie = nil; files[index].series = nil
                    files[index].season = nil; files[index].episode = nil
                }
            }
            loaded = true
            revision += 1
        }
        let libraries: [String] = UserDefaults.standard.value(forKey: UserDefaults.library, default: [])
        for key in Array(accessedURLs.keys) where !libraries.contains(key) {
            accessedURLs.removeValue(forKey: key)?.stopAccessingSecurityScopedResource()
        }
        let roots = libraries.compactMap { library -> (String, URL)? in
            guard let url = resolveFolder(library) else { return nil }
            return (library, url)
        }
        resolvedFolders = Dictionary(uniqueKeysWithValues: roots)
        let previous = files
        let snapshot = await Task.detached(priority: .utility) {
            Self.discover(roots: roots, previous: previous)
        }.value
        // A folder removed while scanning must not reappear in the library.
        let currentLibraries: [String] = UserDefaults.standard.value(forKey: UserDefaults.library, default: [])
        guard libraries == currentLibraries else {
            await scan()
            return
        }
        offlineLibraries = snapshot.offline
        scanErrors = snapshot.errors
        files = snapshot.files
        if snapshot.changed { revision += 1 }
        if snapshot.changed { await save() }
        var identifiedCount = 0
        // Publish filenames before network metadata arrives, including failed matches.
        for file in files where file.isAvailable && !file.didIdentify {
            var updated = file
            updated.error = nil
            do {
                let duration = try await AVURLAsset(url: file.fileURL).load(.duration).seconds
                updated.duration = duration.isFinite ? duration : 0
            } catch { updated.error = error.localizedDescription }
            // Matching must also work for formats AVFoundation cannot probe.
            do {
                if file.fileURL.isVideo && !file.isManuallyMatched {
                    try await identify(&updated)
                } else if !file.fileURL.isVideo {
                    updated.audio = try await readAudio(file)
                }
            } catch {
                updated.error = error.localizedDescription
            }
            updated.didIdentify = true
            if let index = files.firstIndex(where: { $0.id == updated.id }) {
                files[index] = updated
                identifiedCount += 1
                if identifiedCount.isMultiple(of: 25) {
                    revision += 1
                    await save()
                }
            }
        }
        if identifiedCount > 0 {
            revision += 1
            await save()
        }
        let latestLibraries: [String] = UserDefaults.standard.value(forKey: UserDefaults.library, default: [])
        if latestLibraries != libraries { await scan() }
    }

    func folderURL(for library: String) -> URL? { resolvedFolders[library] ?? URL(string: library) }

    private func resolveFolder(_ library: String) -> URL? {
        var url = URL(string: library)
        let bookmarks = UserDefaults.standard.dictionary(forKey: Self.bookmarkKey) as? [String: Data] ?? [:]
        if let data = bookmarks[library] {
            do {
                var stale = false
                #if os(macOS)
                let options: URL.BookmarkResolutionOptions = [.withSecurityScope, .withoutUI]
                #else
                let options: URL.BookmarkResolutionOptions = [.withoutUI]
                #endif
                url = try URL(resolvingBookmarkData: data, options: options,
                              relativeTo: nil, bookmarkDataIsStale: &stale)
                if stale, let url {
                    let accessing = url.startAccessingSecurityScopedResource()
                    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                    #if os(macOS)
                    let creationOptions: URL.BookmarkCreationOptions = [.withSecurityScope, .securityScopeAllowOnlyReadAccess]
                    #else
                    let creationOptions: URL.BookmarkCreationOptions = [.minimalBookmark]
                    #endif
                    var renewed = bookmarks
                    renewed[library] = try url.bookmarkData(options: creationOptions,
                                                           includingResourceValuesForKeys: nil, relativeTo: nil)
                    UserDefaults.standard.set(renewed, forKey: Self.bookmarkKey)
                }
            } catch {
                storageError = error.localizedDescription
            }
        }
        if accessedURLs[library] != url {
            accessedURLs.removeValue(forKey: library)?.stopAccessingSecurityScopedResource()
            if let url, url.startAccessingSecurityScopedResource() { accessedURLs[library] = url }
        }
        return url
    }

    private func readAudio(_ file: LibraryFile) async throws -> LibraryAudioMetadata {
        let url = file.fileURL
        let path = MediaNaming.parseTrack(url, library: folderURL(for: file.library))
        let song = Song(fileURL: url, duration: file.duration)
        // Embedded tags win; `Artist/Album (Year)/Disc 1/01 Title` only fills what they leave empty.
        try? await song.loadMetadata()
        if song.title.isEmpty { song.title = path.title }
        if song.trackNumber == nil { song.trackNumber = path.trackNumber }
        if song.discNumber == nil { song.discNumber = path.discNumber }
        if song.album.title.isEmpty { song.album.title = path.album ?? "" }
        if song.artist.name.isEmpty { song.artist.name = path.artist ?? "" }
        if song.album.artist.name.isEmpty { song.album.artist.name = song.artist.name }
        if song.releaseDate == nil, let year = path.year {
            song.releaseDate = DateComponents(calendar: .current, year: year).date
        }
        if song.album.cover == nil, let cover = MediaNaming.cover(for: url) {
            song.album.cover = try? Data(contentsOf: cover)
        }
        return LibraryAudioMetadata(title: song.title, artist: song.artist.name, album: song.album.title,
            albumArtist: song.album.artist.name, composer: song.composer, lyricist: song.lyricist,
            arranger: song.arranger, releaseDate: song.releaseDate, cover: song.album.cover,
            trackNumber: song.trackNumber, discNumber: song.discNumber ?? 1,
            lyrics: song.lyrics.body.map(LibraryLyric.init))
    }

    private func identify(_ file: inout LibraryFile) async throws {
        let library = folderURL(for: file.library)
        // Trailers, deleted scenes and samples stay in Files without claiming the title.
        guard !MediaNaming.isExtra(file.fileURL, library: library) else { return }
        switch MediaNaming.parseVideo(file.fileURL, library: library) {
        case .episode(let parsed):
            guard let id = try await seriesID(parsed.show, year: parsed.year, tmdbID: parsed.tmdbID) else { return }
            try await assignEpisode(&file, seriesID: id, season: parsed.season, episode: parsed.episode)
        case .movie(let parsed):
            guard let id = try await movieID(parsed) else { return }
            file.movie = try await MetadataCache.shared.movie(id: id)
        case nil:
            return
        }
    }

    /// Every episode of a show resolves through the same cache key, so they group under one series.
    private func seriesID(_ title: String, year: Int?, tmdbID: Int?) async throws -> Int? {
        if let tmdbID { return tmdbID }
        let key = "\(title.lowercased())|\(year.map(String.init) ?? "")"
        if let cached = await MetadataCache.shared.searchResult(for: key, domain: "tv") { return cached }
        var results = try await SearchService.shared.searchTVSeries(query: title, firstAirDateYear: year).results
        if results.isEmpty, year != nil {
            results = try await SearchService.shared.searchTVSeries(query: title).results
        }
        guard let id = results.first?.id else { return nil }
        await MetadataCache.shared.storeSearchResult(id, for: key, domain: "tv")
        return id
    }

    private func movieID(_ movie: MediaNaming.Movie) async throws -> Int? {
        if let id = movie.tmdbID { return id }
        let key = "\(movie.title.lowercased())|\(movie.year.map(String.init) ?? "")"
        if let cached = await MetadataCache.shared.searchResult(for: key, domain: "movie") { return cached }
        var results = try await SearchService.shared.searchMovies(query: movie.title, year: movie.year).results
        if results.isEmpty, let year = movie.year {
            // The number may belong to the title, e.g. `Wonder Woman 1984`.
            results = try await SearchService.shared.searchMovies(query: "\(movie.title) \(year)").results
        }
        guard let id = results.first?.id else { return nil }
        await MetadataCache.shared.storeSearchResult(id, for: key, domain: "movie")
        return id
    }

    private func assignEpisode(_ file: inout LibraryFile, seriesID: Int, season: Int, episode: Int) async throws {
        file.series = try await MetadataCache.shared.tvSeries(id: seriesID)
        file.season = try await MetadataCache.shared.tvSeason(seasonNumber: season, tvSeriesID: seriesID)
        file.episode = try await MetadataCache.shared.tvEpisode(key: "\(seriesID)-s\(season)e\(episode)",
            episodeNumber: episode, seasonNumber: season, tvSeriesID: seriesID)
        file.movie = nil
    }

    func match(fileID: UUID, movieID: Int) async throws {
        await refreshIfScanning()
        guard !isMatching else { throw LibraryMatchError.busy }
        isMatching = true
        defer { isMatching = false }
        let metadata = try await MetadataCache.shared.movie(id: movieID)
        guard let index = files.firstIndex(where: { $0.id == fileID }) else { throw LibraryMatchError.fileMissing }
        var updated = files
        updated[index].movie = metadata
        updated[index].series = nil
        updated[index].season = nil
        updated[index].episode = nil
        updated[index].isManuallyMatched = true
        updated[index].didIdentify = true
        updated[index].error = nil
        try await persist(updated)
        files = updated
        storageError = nil
        revision += 1
    }

    func match(fileID: UUID, seriesID: Int, season: Int, episode: Int, sameShow: Bool) async throws {
        await refreshIfScanning()
        guard !isMatching else { throw LibraryMatchError.busy }
        isMatching = true
        defer { isMatching = false }
        guard let selected = files.first(where: { $0.id == fileID }) else { throw LibraryMatchError.fileMissing }
        let library = folderURL(for: selected.library)
        let showFolder = MediaNaming.showFolder(for: selected.fileURL, library: library)
            ?? selected.fileURL.deletingLastPathComponent()
        var updated = files
        for index in updated.indices {
            let file = updated[index]
            let isSelected = file.id == fileID
            let seasonNumber: Int
            let episodeNumber: Int
            if isSelected {
                seasonNumber = season; episodeNumber = episode
            } else {
                // Season folders of the same show share the selected show.
                guard sameShow, file.fileURL.isVideo, file.library == selected.library,
                      file.fileURL.path.hasPrefix(showFolder.path + "/"),
                      !MediaNaming.isExtra(file.fileURL, library: library),
                      case .episode(let parsed) = MediaNaming.parseVideo(file.fileURL, library: library)
                else { continue }
                seasonNumber = parsed.season; episodeNumber = parsed.episode
            }
            try await assignEpisode(&updated[index], seriesID: seriesID, season: seasonNumber, episode: episodeNumber)
            updated[index].isManuallyMatched = true
            updated[index].didIdentify = true
            updated[index].error = nil
        }
        try await persist(updated)
        files = updated
        storageError = nil
        revision += 1
    }

    func retryUnmatched(library: String?) async {
        await refreshIfScanning()
        guard !isMatching else { return }
        for index in files.indices where files[index].fileURL.isVideo && !files[index].isMatched &&
            (library == nil || files[index].library == library) {
            files[index].didIdentify = false
        }
        await refresh()
    }

    private func refreshIfScanning() async {
        if let scanTask { await scanTask.value }
    }

    private func save() async {
        do { try await persist(files); storageError = nil }
        catch { storageError = error.localizedDescription }
    }

    private func persist(_ files: [LibraryFile]) async throws {
        guard canSave else { throw CocoaError(.fileReadCorruptFile) }
        try await Task.detached(priority: .utility) {
            let encoder = JSONEncoder()
            // TMDb checks date fields as strings before decoding Date. Preserve the
            // full timestamp precision for file modification comparisons as well.
            encoder.dateEncodingStrategy = .custom { date, encoder in
                var container = encoder.singleValueContainer()
                try container.encode(String(date.timeIntervalSinceReferenceDate))
            }
            let data = try encoder.encode(files)
            try FileManager.default.createDirectory(at: Self.indexURL.deletingLastPathComponent(),
                                                     withIntermediateDirectories: true)
            try data.write(to: Self.indexURL, options: .atomic)
        }.value
    }
}

extension LibraryFile: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.fileURL == rhs.fileURL && lhs.library == rhs.library &&
        lhs.modifiedAt == rhs.modifiedAt && lhs.size == rhs.size && lhs.isAvailable == rhs.isAvailable &&
        lhs.duration == rhs.duration && lhs.movie?.id == rhs.movie?.id && lhs.series?.id == rhs.series?.id &&
        lhs.episode?.id == rhs.episode?.id && lhs.isManuallyMatched == rhs.isManuallyMatched &&
        lhs.didIdentify == rhs.didIdentify && lhs.error == rhs.error && lhs.audio == rhs.audio &&
        lhs.localArtwork == rhs.localArtwork
    }
}

extension LibraryViewModel {
    nonisolated private static func discover(roots: [(String, URL)], previous: [LibraryFile])
        -> (files: [LibraryFile], offline: Set<String>, errors: [String], changed: Bool) {
        let manager = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey,
                                      .fileSizeKey, .volumeUUIDStringKey]
        var found: [(String, URL, URLResourceValues, String?)] = []
        var offline: Set<String> = []
        var errors: [String] = []
        var paths: Set<URL> = []
        var images: [String: URL] = [:]
        for (library, root) in roots {
            do {
                // Unlike fileExists this distinguishes permission errors from an empty folder.
                _ = try manager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
                guard let enumerator = manager.enumerator(at: root, includingPropertiesForKeys: keys,
                    options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: { url, error in
                        errors.append("\(url.lastPathComponent): \(error.localizedDescription)")
                        return true
                    }) else { continue }
                for case let url as URL in enumerator {
                    guard let values = try? url.resourceValues(forKeys: Set(keys)),
                          values.isRegularFile == true, values.isSymbolicLink != true else { continue }
                    if url.isImage {
                        images[url.standardizedFileURL.path.lowercased()] = url
                        continue
                    }
                    guard url.isVideo || url.isAudio, paths.insert(url).inserted else { continue }
                    let attributes = try? manager.attributesOfItem(atPath: url.path)
                    let inode = attributes?[.systemFileNumber] as? NSNumber
                    let identity = values.volumeUUIDString.flatMap { volume in inode.map { "\(volume):\($0)" } }
                    found.append((library, url, values, identity))
                }
            } catch {
                offline.insert(library)
                errors.append("\(root.lastPathComponent): \(error.localizedDescription)")
            }
        }
        var remaining = Dictionary(uniqueKeysWithValues: previous.map { ($0.id, $0) })
        var result: [LibraryFile] = []
        let byURL = Dictionary(grouping: previous, by: \.fileURL)
        let byIdentity = Dictionary(grouping: previous.compactMap { file in
            file.fileIdentity.map { ($0, file) }
        }, by: { $0.0 })
        for (library, url, values, identity) in found {
            let old = byURL[url]?.first ?? identity.flatMap { key in
                byIdentity[key]?.map(\.1).first { remaining[$0.id] != nil && !paths.contains($0.fileURL) }
            }
            var file = old ?? LibraryFile(fileURL: url, library: library, namingVersion: MediaNaming.version)
            remaining.removeValue(forKey: file.id)
            if old == nil || file.modifiedAt != values.contentModificationDate || file.size != (values.fileSize ?? 0) {
                file.didIdentify = false
                if !file.isManuallyMatched {
                    file.movie = nil; file.series = nil; file.season = nil; file.episode = nil
                }
            }
            file.fileURL = url
            file.library = library
            file.fileIdentity = identity
            file.modifiedAt = values.contentModificationDate
            file.size = values.fileSize ?? 0
            file.isAvailable = true
            file.localArtwork = url.isVideo
                ? MediaNaming.artwork(for: url, library: roots.first { $0.0 == library }?.1, images: images)
                : nil
            result.append(file)
        }
        let active = Set(roots.map(\.0))
        for var file in remaining.values where active.contains(file.library) {
            file.isAvailable = false
            result.append(file)
        }
        result.sort { $0.fileURL.path.localizedStandardCompare($1.fileURL.path) == .orderedAscending }
        return (result, offline, errors, result != previous)
    }
}

struct LibraryAudioMetadata: Codable, Equatable {
    var title: String
    var artist: String
    var album: String
    var albumArtist: String
    var composer: String
    var lyricist: String
    var arranger: String
    var releaseDate: Date?
    var cover: Data?
    var trackNumber: Int?
    var discNumber: Int?
    var lyrics: [LibraryLyric]
}

struct LibraryLyric: Codable, Equatable {
    var start: TimeInterval
    var end: TimeInterval
    var content: String
    var phrases: [LibraryLyric]

    init(_ lyric: Lyric) {
        start = lyric.start; end = lyric.end; content = lyric.content
        phrases = lyric.phrases.map(LibraryLyric.init)
    }

    var lyric: Lyric {
        Lyric(start: start, end: end, content: content, phrases: phrases.map(\.lyric))
    }
}

private enum LibraryMatchError: LocalizedError {
    case busy, fileMissing

    var errorDescription: String? {
        switch self {
        case .busy: String(localized: "Another match is being saved. Please try again.")
        case .fileMissing: String(localized: "This file is no longer in the library.")
        }
    }
}
