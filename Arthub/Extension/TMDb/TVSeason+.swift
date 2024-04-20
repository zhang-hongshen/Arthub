//
//  TVSeason+.swift
//  Arthub
//
//  Created by 张鸿燊 on 28/2/2024.
//

import Foundation
import TMDb

extension TVSeason {
    func copy(
        name: String? = nil,
        seasonNumber: Int? = nil,
        overview: String? = nil,
        airDate: Date? = nil,
        posterPath: URL? = nil,
        episodes: [TVEpisode]? = nil
    ) -> Self {
        return .init(
            id: self.id,
            name: name ?? self.name,
            seasonNumber: seasonNumber ?? self.seasonNumber,
            overview: overview ?? self.overview,
            airDate: airDate ?? self.airDate,
            posterPath: posterPath ?? self.posterPath,
            episodes: episodes ?? self.episodes
        )
    }
}
