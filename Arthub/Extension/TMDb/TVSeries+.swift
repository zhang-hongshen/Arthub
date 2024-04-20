//
//  TVSeries+.swift
//  Arthub
//
//  Created by 张鸿燊 on 28/2/2024.
//

import Foundation
import TMDb

extension TVSeries {
    
    func copy(
        name: String? = nil,
        tagline: String? = nil,
        originalName: String? = nil,
        originalLanguage: String? = nil,
        overview: String? = nil,
        episodeRunTime: [Int]? = nil,
        numberOfSeasons: Int? = nil,
        numberOfEpisodes: Int? = nil,
        seasons: [TVSeason]? = nil,
        genres: [Genre]? = nil,
        firstAirDate: Date? = nil,
        originCountry: [String]? = nil,
        posterPath: URL? = nil,
        backdropPath: URL? = nil,
        homepageURL: URL? = nil,
        isInProduction: Bool? = nil,
        languages: [String]? = nil,
        lastAirDate: Date? = nil,
        networks: [Network]? = nil,
        productionCompanies: [ProductionCompany]? = nil,
        status: String? = nil,
        type: String? = nil,
        popularity: Double? = nil,
        voteAverage: Double? = nil,
        voteCount: Int? = nil,
        isAdultOnly: Bool? = nil
    ) -> Self {
        return .init(
            id: self.id,
            name: name ?? self.name,
            tagline: tagline ?? self.tagline,
            originalName: originalName ?? self.originalName,
            originalLanguage: originalLanguage ?? self.originalLanguage,
            overview: overview ?? self.overview,
            episodeRunTime: episodeRunTime ?? self.episodeRunTime,
            numberOfSeasons: numberOfSeasons ?? self.numberOfSeasons,
            numberOfEpisodes: numberOfEpisodes ?? self.numberOfEpisodes,
            seasons: seasons ?? self.seasons,
            genres: genres ?? self.genres,
            firstAirDate: firstAirDate ?? self.firstAirDate,
            originCountry: originCountry ?? self.originCountry,
            posterPath: posterPath ?? self.posterPath,
            backdropPath: backdropPath ?? self.backdropPath,
            homepageURL: homepageURL ?? self.homepageURL,
            isInProduction: isInProduction ?? self.isInProduction,
            languages: languages ?? self.languages,
            lastAirDate: lastAirDate ?? self.lastAirDate,
            networks: networks ?? self.networks,
            productionCompanies: productionCompanies ?? self.productionCompanies,
            status: status ?? self.status,
            type: type ?? self.type,
            popularity: popularity ?? self.popularity,
            voteAverage: voteAverage ?? self.voteAverage,
            voteCount: voteCount ?? self.voteCount,
            isAdultOnly: isAdultOnly ?? self.isAdultOnly
        )
    }

}
