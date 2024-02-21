//
//  TMDbMovieMetadata+.swift
//  Arthub
//
//  Created by 张鸿燊 on 17/2/2024.
//
import Foundation
import TMDb
import struct TMDb.Movie

extension Movie {
    
    func copy(
        id: Int? = nil,
        title: String? = nil,
        tagline: String? = nil,
        originalTitle: String? = nil,
        originalLanguage: String? = nil,
        overview: String? = nil,
        runtime: Int? = nil,
        genres: [Genre]? = nil,
        releaseDate: Date? = nil,
        posterPath: URL? = nil,
        backdropPath: URL? = nil,
        budget: Double? = nil,
        revenue: Double? = nil,
        homepageURL: URL? = nil,
        imdbID: String? = nil,
        status: Status? = nil,
        productionCompanies: [ProductionCompany]? = nil,
        productionCountries: [ProductionCountry]? = nil,
        spokenLanguages: [SpokenLanguage]? = nil,
        popularity: Double? = nil,
        voteAverage: Double? = nil,
        voteCount: Int? = nil,
        hasVideo: Bool? = nil,
        isAdultOnly: Bool? = nil
    ) -> Self {
        return Self(
            id: id ?? self.id,
            title: title ?? self.title,
            tagline: tagline ?? self.tagline,
            originalTitle: originalTitle ?? self.originalTitle,
            originalLanguage: originalLanguage ?? self.originalLanguage,
            overview: overview ?? self.overview,
            runtime: runtime ?? self.runtime,
            genres: genres ?? self.genres,
            releaseDate: releaseDate ?? self.releaseDate,
            posterPath: posterPath ?? self.posterPath,
            backdropPath: backdropPath ?? self.backdropPath,
            budget: budget ?? self.budget,
            revenue: revenue ?? self.revenue,
            homepageURL: homepageURL ?? self.homepageURL,
            imdbID: imdbID ?? self.imdbID,
            status: status ?? self.status,
            productionCompanies: productionCompanies ?? self.productionCompanies,
            productionCountries: productionCountries ?? self.productionCountries,
            spokenLanguages: spokenLanguages ?? self.spokenLanguages,
            popularity: popularity ?? self.popularity,
            voteAverage: voteAverage ?? self.voteAverage,
            voteCount: voteCount ?? self.voteCount,
            hasVideo: hasVideo ?? self.hasVideo,
            isAdultOnly: isAdultOnly ?? self.isAdultOnly
        )
    }
}
