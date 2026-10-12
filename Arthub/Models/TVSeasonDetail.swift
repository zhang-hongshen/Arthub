//
//  TVSeasonDetail.swift
//  Arthub
//
//  Created by 张鸿燊 on 28/2/2024.
//

import Foundation
import TMDb

@Observable
class TVSeasonDetail: Identifiable, Hashable {
    
    var id: TVSeason.ID { metadata.id }
    var tvShowID: Int
    var metadata: TVSeason
    var episodes: Set<TVEpisodeDetail>
    var posters: [ImageMetadata] = []
    
    init(tvShowID: Int, metadata: TVSeason,
         episodes: Set<TVEpisodeDetail> = []) {
        self.tvShowID = tvShowID
        self.metadata = metadata
        self.episodes = episodes
    }
    
    static func ==(lhs: TVSeasonDetail, rhs: TVSeasonDetail) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: computed property

extension TVSeasonDetail {
    
    var duration: TimeInterval {
        episodes.reduce(0) { result, episode in
            result + episode.duration
        }
    }
    
    var progress: Double {
        let watchedTime = episodes.reduce(0) { result, episode in
            result + episode.metrics.currentTime
        }
        return duration != 0 ? Double(watchedTime) / Double(duration) : 0
    }
    
    var lastWatchingEpisode: TVEpisodeDetail? {
        episodes.sorted(using: KeyPathComparator(\.metrics.watchedAt, order: .reverse)).first
    }
}

extension TVSeasonDetail {

    func fetchDetail() async throws {
        async let images = ConfigurationService.shared.getImageConfiguration()
        async let details = TVSeasonService.shared.details(forSeason: metadata.seasonNumber, inTVSeries: tvShowID)
        let config = try await images
        let metadata = try await details
        // Local artwork found next to the files wins over TMDb.
        let localPoster = self.metadata.posterPath.flatMap { $0.isFileURL ? $0 : nil }
        self.metadata = metadata.copy(posterPath: localPoster ?? config.posterURL(for: metadata.posterPath))
    }

    /// Posters from TMDb.
    func fetchRelatedData() async throws {
        async let images = ConfigurationService.shared.getImageConfiguration()
        async let artwork = TVSeasonService.shared.images(forSeason: metadata.seasonNumber, inTVSeries: tvShowID)
        let config = try await images
        posters = try await artwork.posters.map { $0.copy(filePath: config.posterURL(for: $0.filePath)) }
    }
}
