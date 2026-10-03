//
//  TVShowsViewModel.swift
//  Arthub
//
//  Created by 张鸿燊 on 18/3/2024.
//

import Foundation
import OrderedCollections
import TMDb
import AVFoundation

@MainActor @Observable class TVShowsViewModel {

    var tvShows: Set<TVShowDetail> = []
    var isFetchingData: Bool = false
    var searchText: String = ""
    var scanErrors: [String] = []
    @ObservationIgnored var sectionMaxTVShow = 10

    var filteredTVShows: Set<TVShowDetail> {
        if searchText.isEmpty {
            return tvShows
        }
        let search = searchText.lowercased()
        return tvShows.filter {
            if let originalName = $0.metadata.originalName,
                originalName.contains(search) {
                return true
            }
            return $0.metadata.name.lowercased().contains(search)
        }
    }

    var recentlyAddedTVShows: [TVShowDetail] {
        filteredTVShows.sorted(using: KeyPathComparator(\.addedAt, order: .reverse))
    }

    var popularityTVShows: [TVShowDetail] {
        filteredTVShows.sorted(using: KeyPathComparator(\.metadata.popularity, order: .reverse))
    }

    var groupedTVShows: OrderedDictionary<String, [TVShowDetail]> {
        var res: OrderedDictionary<String, [TVShowDetail]> = [:]
        filteredTVShows.forEach { tvShow in
            guard let genres = tvShow.metadata.genres else { return }
            genres.map{ $0.name }.forEach { genre in
                res.updateValue(forKey: genre, default: []) { $0.append(tvShow)}
            }
        }
        res.sort()
        return res
    }

    @ObservationIgnored private var fetchDataTask: Task<Void, Never>? = nil

    deinit {
        fetchDataTask?.cancel()
    }

    func fetchData() { fetchData(refreshLibrary: true) }

    func fetchData(refreshLibrary: Bool) {
        fetchDataTask?.cancel()
        isFetchingData = true
        fetchDataTask = Task {
            let library = LibraryViewModel.shared
            if refreshLibrary { await library.refresh() }
            guard !Task.isCancelled else { return }
            let previousShows = Dictionary(uniqueKeysWithValues: tvShows.map { ($0.id, $0) })
            let previousEpisodes = Dictionary(uniqueKeysWithValues: tvShows.flatMap { $0.seasons.flatMap { $0.episodes } }.map { ($0.fileID, $0) })
            var result: [Int: TVShowDetail] = [:]
            var errors = library.scanErrors
            for file in library.files {
                guard let series = file.seriesWithArtwork, let seasonMetadata = file.seasonWithArtwork,
                      let episodeMetadata = file.episodeWithArtwork else { continue }
                do {
                    let episode: TVEpisodeDetail
                    if let existing = previousEpisodes[file.id], existing.metadata.id == episodeMetadata.id {
                        episode = existing
                        episode.metadata = episodeMetadata
                        episode.fileURL = file.fileURL
                        episode.duration = file.duration
                    } else {
                        episode = TVEpisodeDetail(tvShowID: series.id, fileURL: file.fileURL,
                            duration: file.duration, metrics: try await UserMetrics.getByTMDbID(episodeMetadata.id),
                            metadata: episodeMetadata, fileID: file.id)
                    }
                    guard !Task.isCancelled else { return }
                    episode.isAvailable = file.isAvailable
                    let show = result[series.id] ?? TVShowDetail(addedAt: file.addedAt, metadata: series)
                    let season = show.seasons.first { $0.metadata.seasonNumber == seasonMetadata.seasonNumber }
                        ?? TVSeasonDetail(tvShowID: series.id, metadata: seasonMetadata)
                    season.episodes.insert(episode)
                    show.seasons.insert(season)
                    result[series.id] = show
                } catch { errors.append("\(file.title): \(error.localizedDescription)") }
            }
            guard !Task.isCancelled else { return }
            let retained = Set(result.values.flatMap { $0.seasons.flatMap { $0.episodes.map(\.fileID) } })
            for (id, episode) in previousEpisodes where !retained.contains(id) { episode.isAvailable = false }
            // Update existing show/season objects so open detail pages reflect disk changes.
            for (id, show) in result {
                guard let existing = previousShows[id] else { continue }
                var seasons: Set<TVSeasonDetail> = []
                for season in show.seasons {
                    if let oldSeason = existing.seasons.first(where: { $0.id == season.id }) {
                        oldSeason.metadata = oldSeason.metadata.copy(posterPath: season.metadata.posterPath)
                        oldSeason.episodes = season.episodes
                        seasons.insert(oldSeason)
                    } else { seasons.insert(season) }
                }
                existing.metadata = existing.metadata.copy(posterPath: show.metadata.posterPath,
                                                           backdropPath: show.metadata.backdropPath)
                existing.seasons = seasons
                result[id] = existing
            }
            tvShows = Set(result.values)
            scanErrors = errors
            isFetchingData = false
        }
    }
}
