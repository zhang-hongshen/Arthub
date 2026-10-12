//
//  TVShowDetail.swift
//  Arthub
//
//  Created by 张鸿燊 on 28/2/2024.
//

import Foundation
import TMDb

@Observable
class TVShowDetail: Identifiable, Hashable{
    
    var id: TVSeries.ID { metadata.id }
    var addedAt: Date?
    var metadata: TVSeries
    var seasons: Set<TVSeasonDetail>
    var cast: [CastMember] = []
    var crew: [CrewMember] = []
    
    init(addedAt: Date? = nil, metadata: TVSeries,
         seasons: Set<TVSeasonDetail> = []) {
        self.addedAt = addedAt
        self.metadata = metadata
        self.seasons = seasons
    }
    
    static func ==(lhs: TVShowDetail, rhs: TVShowDetail) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
}

// MARK: computed property

extension TVShowDetail{
    
    var duration: TimeInterval {
        seasons.reduce(0) { result, season in
            result + season.episodes.reduce(0) { $0 + $1.duration }
        }
    }
    
    var progress: Double {
        let watchedTime = seasons.reduce(0) { result, season in
            result + season.episodes.reduce(0) { $0 + $1.metrics.currentTime }
        }
        return duration != 0 ? Double(watchedTime) / Double(duration) : 0
    }

}

extension TVShowDetail {

    /// Cast and crew from TMDb.
    func fetchRelatedData() async throws {
        async let images = ConfigurationService.shared.getImageConfiguration()
        async let credits = TVSeriesService.shared.credits(forTVSeries: metadata.id)
        let config = try await images
        cast = try await credits.cast.map { $0.copy(profilePath: config.profileURL(for: $0.profilePath)) }
        crew = try await credits.crew.map { $0.copy(profilePath: config.profileURL(for: $0.profilePath)) }
    }
}
