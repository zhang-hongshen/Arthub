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

    /// Cached entries older than this are fetched again.
    private let expiryInterval: TimeInterval = 60 * 60 * 24 * 7 // 1 week

    private let directory = URL.applicationSupportDirectory
        .appending(path: "Arthub/MetadataCache", directoryHint: .isDirectory)
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private init() {
        // TMDb writes dates as `yyyy-MM-dd`, so cached entries are written the same way.
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        decoder.dateDecodingStrategy = .formatted(formatter)
        encoder.dateEncodingStrategy = .formatted(formatter)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func value<T: Codable>(of type: T.Type, domain: String, id: String) -> T? {
        let file = fileURL(domain: domain, id: id)
        guard let modifiedAt = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
              Date.now.timeIntervalSince(modifiedAt) < expiryInterval,
              let data = try? Data(contentsOf: file) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    func store<T: Codable>(_ value: T, domain: String, id: String) {
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: fileURL(domain: domain, id: id), options: .atomic)
    }

    private func fileURL(domain: String, id: String) -> URL {
        directory.appending(path: "\(domain)-\(id).json")
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
