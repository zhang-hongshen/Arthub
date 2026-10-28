//
//  TVEpisode.swift
//  Arthub
//
//  Created by 张鸿燊 on 28/2/2024.
//

import Foundation
import TMDb
import MediaPlayer


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
        duration != 0 ? metrics.currentTime / duration : 0
    }

    /// What the player and the system's Now Playing panel show for this episode.
    func playlistItem() async -> PlaylistItem {
        var item = PlaylistItem(id: id, url: fileURL, title: metadata.name)
        if versions.count > 1 {
            // The widths come from the files only now, so the sharpest version plays by default.
            item.versions = await versions.loadingWidths()
            item.url = item.versions[0].fileURL
        }
        if let still = metadata.stillPath {
            item.artwork = await MPMediaItemArtwork(contentsOf: still)
        }
        return item
    }

}

extension TVEpisodeDetail {

    func fetchDetail() async throws {
        async let images = ConfigurationService.shared.getImageConfiguration()
        async let details = TVEpisodeService.shared.details(forEpisode: metadata.episodeNumber,
                                                             inSeason: metadata.seasonNumber, inTVSeries: tvShowID)
        let config = try await images
        let metadata = try await details
        // Local artwork found next to the file wins over TMDb.
        let localStill = self.metadata.stillPath.flatMap { $0.isFileURL ? $0 : nil }
        self.metadata = metadata.copy(stillPath: localStill ?? config.stillURL(for: metadata.stillPath))
    }
}
