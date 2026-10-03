//
//  TVEpisode.swift
//  Arthub
//
//  Created by 张鸿燊 on 28/2/2024.
//

import Foundation
import TMDb


@Observable
class TVEpisodeDetail: MediaItem, Identifiable, Hashable {
    
    var id: TVEpisode.ID { metadata.id }
    let fileID: UUID
    var tvShowID: Int
    var metrics: UserMetrics
    var metadata: TVEpisode
    
    init(tvShowID: Int, fileURL: URL, duration: TimeInterval,
         metrics: UserMetrics, metadata: TVEpisode, fileID: UUID = UUID()) {
        self.fileID = fileID
        self.tvShowID = tvShowID
        self.metrics = metrics
        self.metadata = metadata
        super.init(fileURL: fileURL, duration: duration)
    }
    
    static func ==(lhs: TVEpisodeDetail, rhs: TVEpisodeDetail) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: Computed Property

extension TVEpisodeDetail {
    
    var progress: Double {
        return duration != 0 ? Double(metrics.currentTime) / Double(duration) : 0
    }

}

extension TVEpisodeDetail {
    
    func fetchDetail() async throws {
        async let getImageConfiguration = ConfigurationService.shared.getImageConfiguration()
        async let getMetadata = TVEpisodeService.shared.details(forEpisode: metadata.episodeNumber, inSeason: metadata.seasonNumber, inTVSeries: tvShowID)
        let (imagesConfiguration, metadata) = try await(getImageConfiguration, getMetadata)
        // Local artwork found next to the file wins over TMDb.
        let localStill = self.metadata.stillPath.flatMap { $0.isFileURL ? $0 : nil }
        self.metadata = metadata.copy(
            stillPath: localStill ?? imagesConfiguration.stillURL(for: metadata.stillPath)
        )
    }
}
