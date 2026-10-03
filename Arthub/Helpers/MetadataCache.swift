//
//  MetadataCache.swift
//  Arthub
//
//  Created by 张鸿燊 on 25/9/2026.
//

import Foundation
import TMDb

/// Disk cache for TMDb metadata entities, keyed by entity type and ID.
///
/// Library rescans re-discover the same files over and over; this cache
/// prevents re-querying the TMDb API for media whose metadata hasn't
/// changed. Entries live in Application Support/Arthub/MetadataCache
/// and expire after `expiryInterval`.
actor MetadataCache {

    static let shared = MetadataCache()

    /// Cached entries older than this are re-fetched.
    private let expiryInterval: TimeInterval = 60 * 60 * 24 * 7 // 1 week

    private let fileManager = FileManager.default
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let directory: URL

    /// TMDb encodes dates as `yyyy-MM-dd`; this is the inverse so cached
    /// blobs round-trip identically.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private init(directory: URL? = nil) {
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .formatted(Self.dateFormatter)
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .formatted(Self.dateFormatter)

        let baseDirectory = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Arthub/MetadataCache", directoryHint: .isDirectory)
        self.directory = baseDirectory
        try? FileManager.default.createDirectory(at: baseDirectory,
                                                 withIntermediateDirectories: true)
    }

    // MARK: Read

    func value<T: Codable>(of type: T.Type, domain: String, id: String) -> T? {
        guard let data = contents(at: fileURL(domain: domain, id: id)) else { return nil }
        guard !isStale(fileURL: fileURL(domain: domain, id: id)) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    // MARK: Write

    func store<T: Codable>(_ value: T, domain: String, id: String) {
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: fileURL(domain: domain, id: id), options: .atomic)
    }

    // MARK: Maintenance

    /// Remove entries older than the expiry interval.
    func removeExpired() {
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return
        }
        for file in files where isStale(fileURL: file) {
            try? fileManager.removeItem(at: file)
        }
    }

    func removeAll() {
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil) else {
            return
        }
        for file in files {
            try? fileManager.removeItem(at: file)
        }
    }

    // MARK: Private

    private func fileURL(domain: String, id: String) -> URL {
        directory
            .appending(path: "\(domain)-\(id).json", directoryHint: .notDirectory)
    }

    private func contents(at url: URL) -> Data? {
        try? Data(contentsOf: url)
    }

    private func isStale(fileURL: URL) -> Bool {
        guard let modifiedAt = try? fileURL
            .resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate else {
            return true
        }
        return Date.now.timeIntervalSince(modifiedAt) > expiryInterval
    }
}

// MARK: - Cached TMDb lookups

extension MetadataCache {

    func movie(id: TMDb.Movie.ID) async throws -> TMDb.Movie {
        if let cached: TMDb.Movie = value(of: TMDb.Movie.self, domain: "movie", id: "\(id)") {
            return cached
        }
        let movie = try await MovieService.shared.details(forMovie: id)
        let imagesConfiguration = try await ConfigurationService.shared.getImageConfiguration()
        let fullMovie = movie.copy(
            posterPath: imagesConfiguration.posterURL(for: movie.posterPath),
            backdropPath: imagesConfiguration.backdropURL(for: movie.backdropPath)
        )
        store(fullMovie, domain: "movie", id: "\(id)")
        return fullMovie
    }

    func tvSeries(id: TVSeries.ID) async throws -> TVSeries {
        if let cached: TVSeries = value(of: TVSeries.self, domain: "tvseries", id: "\(id)") {
            return cached
        }
        let series = try await TVSeriesService.shared.details(forTVSeries: id)
        let imagesConfiguration = try await ConfigurationService.shared.getImageConfiguration()
        let fullSeries = series.copy(
            posterPath: imagesConfiguration.posterURL(for: series.posterPath),
            backdropPath: imagesConfiguration.backdropURL(for: series.backdropPath)
        )
        store(fullSeries, domain: "tvseries", id: "\(id)")
        return fullSeries
    }

    /// Season lookup. Keyed by "showID-seasonNumber" since TMDb season IDs
    /// aren't known before the first fetch.
    func tvSeason(seasonNumber: Int, tvSeriesID: TVSeries.ID) async throws -> TVSeason {
        let key = "\(tvSeriesID)-s\(seasonNumber)"
        if let cached: TVSeason = value(of: TVSeason.self, domain: "tvseason", id: key) {
            return cached
        }
        let season = try await TVSeasonService.shared.details(forSeason: seasonNumber,
                                                              inTVSeries: tvSeriesID)
        let imagesConfiguration = try await ConfigurationService.shared.getImageConfiguration()
        let fullSeason = season.copy(
            posterPath: imagesConfiguration.posterURL(for: season.posterPath)
        )
        store(fullSeason, domain: "tvseason", id: key)
        return fullSeason
    }

    /// Episode lookup keyed by "showID-seasonNumber-episodeNumber", because
    /// the TMDb episode ID isn't known before the first fetch.
    func tvEpisode(key: String, episodeNumber: Int, seasonNumber: Int,
                   tvSeriesID: TVSeries.ID) async throws -> TVEpisode {
        if let cached: TVEpisode = value(of: TVEpisode.self, domain: "tvepisode", id: key) {
            return cached
        }
        let episode = try await TVEpisodeService.shared.details(forEpisode: episodeNumber,
                                                               inSeason: seasonNumber,
                                                               inTVSeries: tvSeriesID)
        let imagesConfiguration = try await ConfigurationService.shared.getImageConfiguration()
        let fullEpisode = episode.copy(
            stillPath: imagesConfiguration.stillURL(for: episode.stillPath)
        )
        store(fullEpisode, domain: "tvepisode", id: key)
        return fullEpisode
    }

    func person(id: TMDb.Person.ID) async throws -> TMDb.Person {
        if let cached: TMDb.Person = value(of: TMDb.Person.self, domain: "person", id: "\(id)") {
            return cached
        }
        let person = try await PersonService.shared.details(forPerson: id)
        let imagesConfiguration = try await ConfigurationService.shared.getImageConfiguration()
        let fullPerson = person.copy(
            profilePath: imagesConfiguration.profileURL(for: person.profilePath)
        )
        store(fullPerson, domain: "person", id: "\(id)")
        return fullPerson
    }
}

// MARK: - Search result caching

extension MetadataCache {

    /// Cache the *result ID* of a title search, so a file that keeps
    /// reappearing in scans doesn't re-trigger the search API call.
    func searchResult(for query: String, domain: String) -> Int? {
        value(of: Int.self, domain: "search-\(domain)", id: query.normalizedSearchKey)
    }

    func storeSearchResult(_ id: Int, for query: String, domain: String) {
        store(id, domain: "search-\(domain)", id: query.normalizedSearchKey)
    }
}

private extension String {
    var normalizedSearchKey: String {
        self.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? self
    }
}
