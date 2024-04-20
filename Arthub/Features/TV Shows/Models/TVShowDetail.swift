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
    
    func fetchRelatedData() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask{ try await self.fetchCredits() }
            try await group.waitForAll()
        }
    }
    
    func fetchCredits() async throws  {
        async let getImageConfiguration = ConfigurationService.shared.getImageConfiguration()
        async let fetchCredits = try await TVSeriesService.shared.credits(forTVSeries: metadata.id)
        let (imagesConfiguration, credits) = try await(getImageConfiguration, fetchCredits)
        
        await withTaskGroup(of: Void.self) { group in
            
            group.addTask {
                var cast: [CastMember] = []
                for castMember in credits.cast {
                    cast.append(castMember.copy(
                        profilePath: imagesConfiguration.profileURL(for: castMember.profilePath)))
                }
                self.cast = cast
            }
            
            group.addTask {
                var crew: [CrewMember] = []
                for crewMember in credits.crew {
                    crew.append(crewMember.copy(
                        profilePath: imagesConfiguration.profileURL(for: crewMember.profilePath)))
                }
                self.crew = crew
            }
            await group.waitForAll()
        }
    }
}
