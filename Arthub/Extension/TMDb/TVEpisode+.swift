//
//  TVEpisode+.swift
//  Arthub
//
//  Created by 张鸿燊 on 28/2/2024.
//

import Foundation
import TMDb

extension TVEpisode {
    
    func copy(
        name: String? = nil,
        episodeNumber: Int? = nil,
        seasonNumber: Int? = nil,
        overview: String? = nil,
        airDate: Date? = nil,
        productionCode: String? = nil,
        stillPath: URL? = nil,
        crew: [CrewMember]? = nil,
        guestStars: [CastMember]? = nil,
        voteAverage: Double? = nil,
        voteCount: Int? = nil
    ) -> Self {
        return .init(
            id: self.id,
            name: name ?? self.name,
            episodeNumber: episodeNumber ?? self.episodeNumber,
            seasonNumber: seasonNumber ?? self.seasonNumber,
            overview: overview ?? self.overview,
            airDate: airDate ?? self.airDate,
            productionCode: productionCode ?? self.productionCode,
            stillPath: stillPath ?? self.stillPath,
            crew: crew ?? self.crew,
            guestStars: guestStars ?? self.guestStars,
            voteAverage: voteAverage ?? self.voteAverage,
            voteCount: voteCount ?? self.voteCount
        )
    }

}
