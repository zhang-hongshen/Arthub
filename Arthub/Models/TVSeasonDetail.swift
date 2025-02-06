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
        async let getImageConfiguration = ConfigurationService.shared.getImageConfiguration()
        async let getMetadata = TVSeasonService.shared.details(forSeason: metadata.seasonNumber, inTVSeries: tvShowID)
        let (imagesConfiguration, metadata) = try await(getImageConfiguration, getMetadata)
        self.metadata = metadata.copy(
            posterPath: imagesConfiguration.posterURL(for: metadata.posterPath)
        )
    }
    
    func fetchRelatedData() async throws {
        try await fetchImages()
    }
    
    func fetchImages() async throws {
        async let getImageConfiguration = ConfigurationService.shared.getImageConfiguration()
        async let getImages = TVSeasonService.shared.images(forSeason: metadata.seasonNumber, inTVSeries: tvShowID)
        let (imagesConfiguration, images) = try await(getImageConfiguration, getImages)
        var posters: [ImageMetadata] = []
        images.posters.forEach { image in
            posters.append(image.copy(
                filePath: imagesConfiguration.posterURL(for: image.filePath)
            ))
        }
        self.posters = posters
    }
    
}
