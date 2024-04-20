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

@Observable class TVShowsViewModel {
    
    var tvShows: Set<TVShowDetail> = []
    private var fetchDataTask: Task<Void, Error>? = nil
    var isFetchingData: Bool = false
    var searchText: String = ""

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
    
    deinit {
        fetchDataTask?.cancel()
    }
    
    func fetchData() {
        isFetchingData = true
        fetchDataTask?.cancel()
        fetchDataTask = Task(priority: .userInitiated) {
            
            let tvShows = try await withThrowingTaskGroup(of: Set<TVShowDetail>.self) { group in
                var tvShows: Set<TVShowDetail> = []
                
                group.addTask { 
                    let res = try await self.fetchLocalData()
                    return res
                }
                for try await result in group {
                    tvShows.formUnion(result)
                }
                return tvShows
            }
            DispatchQueue.main.async {

                self.tvShows.formUnion(tvShows)
                // delete not exist element
                self.tvShows.formIntersection(tvShows)
                self.isFetchingData = false
            }
        }
    }
    
    private func fetchLocalData() async throws -> Set<TVShowDetail> {
        
        let urls = UserDefaults.standard.value(forKey: UserDefaults.localTVShowsData, default: [])
            .compactMap { URL(string: $0) }
        return try await fetchMultiDirectoryData(urls)
    }
    
    private func fetchMultiDirectoryData(_ urls: [URL]) async throws -> Set<TVShowDetail> {
        var tvShows: Set<TVShowDetail> = []
        for url in urls {
            try await fetchDirectoryData(url, tvShows: &tvShows)
        }
        return tvShows
    }
    
    private func fetchDirectoryData(_ dir: URL, tvShows: inout Set<TVShowDetail>) async throws {
        guard dir.hasDirectoryPath else { return }
        let urls = try FileManager.default
            .contentsOfDirectory(at: dir,
                             includingPropertiesForKeys: nil,
                             options: [.skipsHiddenFiles])
        for url in urls {
            if url.hasDirectoryPath {
                try await fetchDirectoryData(url, tvShows: &tvShows)
                debugPrint("found directory, path \(url.relativePath)")
                continue
            }
            if !url.isVideo { continue }
            guard let matches = url.fileName.wholeMatch(of: RegexPattern.tvepisodeName),
                  let seasonNum = Int(matches.output.seasonNum),
                  let episodeNum = Int(matches.output.episodeNum) else {
                continue
            }
            let title = String(matches.output.title)
            var tvShow = tvShows.first { $0.metadata.name == title }
            if tvShow == nil {
                let newTVShow = TVShowDetail(addedAt: url.addedAt, metadata: try await searchTVShowMetadata(title: title))
                tvShow = newTVShow
                tvShows.insert(newTVShow)
            }
            guard let tvShow else { continue }
            let episodeMetadata = try await TVEpisodeService.shared.details(forEpisode: episodeNum, inSeason: seasonNum, inTVSeries: tvShow.id)
            let metrics = try await UserMetrics.getByTMDbID(episodeMetadata.id)
            let duration = try await AVURLAsset(url: url).load(.duration).seconds

            let episode = TVEpisodeDetail(tvShowID: tvShow.id, fileURL: url,
                                          duration: duration, metrics: metrics, metadata: episodeMetadata)
            // add episode to season
            let season = tvShow.seasons.first {
                $0.tvShowID == tvShow.id &&
                $0.metadata.seasonNumber == seasonNum
            }
            guard let season else {
                tvShow.seasons.insert(
                    TVSeasonDetail(tvShowID: tvShow.id,
                                   metadata: try await TVSeasonService.shared.details(forSeason: seasonNum, inTVSeries: tvShow.id),
                                   episodes: [episode]))
                continue
            }
            season.episodes.insert(episode)
        }
    }
    
    
    private func searchTVShowMetadata(title: String, year: Int? = nil) async throws -> TVSeries {
        guard var metadata = try await SearchService.shared.searchTVSeries(query: title, firstAirDateYear: year).results.first else {
            return TVSeries(id: UUID().hashValue, name: title)
        }
        let imagesConfiguration = try await ConfigurationService.shared.getImageConfiguration()
        metadata = try await TVSeriesService.shared.details(forTVSeries: metadata.id)
        return metadata.copy(
            posterPath: imagesConfiguration.posterURL(for: metadata.posterPath),
            backdropPath: imagesConfiguration.backdropURL(for: metadata.backdropPath))
    }
}
