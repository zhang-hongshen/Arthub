//
//  TMDb+.swift
//  Arthub
//
//  Created by 张鸿燊 on 17/2/2024.
//

import Foundation
import TMDb

// MARK: Services

extension ConfigurationService {
    static let shared = ConfigurationService()

    func getImageConfiguration() async throws -> ImagesConfiguration {
        try await apiConfiguration().images
    }
}

extension MovieService { static let shared = MovieService() }
extension PersonService { static let shared = PersonService() }
extension SearchService { static let shared = SearchService() }
extension TVSeriesService { static let shared = TVSeriesService() }
extension TVSeasonService { static let shared = TVSeasonService() }
extension TVEpisodeService { static let shared = TVEpisodeService() }

// MARK: Image URLs
// TMDb models can't be changed, so these make a copy with full image URLs in place of TMDb's paths.

extension TMDb.Movie {
    func copy(posterPath: URL?, backdropPath: URL?) -> Self {
        Self(id: id, title: title, tagline: tagline, originalTitle: originalTitle,
             originalLanguage: originalLanguage, overview: overview, runtime: runtime, genres: genres,
             releaseDate: releaseDate, posterPath: posterPath ?? self.posterPath,
             backdropPath: backdropPath ?? self.backdropPath, budget: budget, revenue: revenue,
             homepageURL: homepageURL, imdbID: imdbID, status: status, productionCompanies: productionCompanies,
             productionCountries: productionCountries, spokenLanguages: spokenLanguages, popularity: popularity,
             voteAverage: voteAverage, voteCount: voteCount, hasVideo: hasVideo, isAdultOnly: isAdultOnly)
    }
}

extension TVSeries {
    func copy(posterPath: URL?, backdropPath: URL?) -> Self {
        Self(id: id, name: name, tagline: tagline, originalName: originalName, originalLanguage: originalLanguage,
             overview: overview, episodeRunTime: episodeRunTime, numberOfSeasons: numberOfSeasons,
             numberOfEpisodes: numberOfEpisodes, seasons: seasons, genres: genres, firstAirDate: firstAirDate,
             originCountry: originCountry, posterPath: posterPath ?? self.posterPath,
             backdropPath: backdropPath ?? self.backdropPath, homepageURL: homepageURL,
             isInProduction: isInProduction, languages: languages, lastAirDate: lastAirDate, networks: networks,
             productionCompanies: productionCompanies, status: status, type: type, popularity: popularity,
             voteAverage: voteAverage, voteCount: voteCount, isAdultOnly: isAdultOnly)
    }
}

extension TVSeason {
    func copy(posterPath: URL?) -> Self {
        Self(id: id, name: name, seasonNumber: seasonNumber, overview: overview, airDate: airDate,
             posterPath: posterPath ?? self.posterPath, episodes: episodes)
    }
}

extension TVEpisode {
    func copy(stillPath: URL?) -> Self {
        Self(id: id, name: name, episodeNumber: episodeNumber, seasonNumber: seasonNumber, overview: overview,
             airDate: airDate, productionCode: productionCode, stillPath: stillPath ?? self.stillPath,
             crew: crew, guestStars: guestStars, voteAverage: voteAverage, voteCount: voteCount)
    }
}

extension TMDb.Person {
    func copy(profilePath: URL?) -> Self {
        Self(id: id, name: name, alsoKnownAs: alsoKnownAs, knownForDepartment: knownForDepartment,
             biography: biography, birthday: birthday, deathday: deathday, gender: gender,
             placeOfBirth: placeOfBirth, profilePath: profilePath ?? self.profilePath,
             popularity: popularity, imdbID: imdbID, homepageURL: homepageURL)
    }
}

extension CastMember {
    func copy(profilePath: URL?) -> Self {
        Self(id: id, castID: castID, creditID: creditID, name: name, character: character, gender: gender,
             profilePath: profilePath ?? self.profilePath, order: order)
    }
}

extension CrewMember {
    func copy(profilePath: URL?) -> Self {
        Self(id: id, creditID: creditID, name: name, job: job, department: department, gender: gender,
             profilePath: profilePath ?? self.profilePath)
    }
}

extension ImageMetadata {
    func copy(filePath: URL?) -> Self {
        Self(filePath: filePath ?? self.filePath, width: width, height: height, aspectRatio: aspectRatio,
             voteAverage: voteAverage, voteCount: voteCount, languageCode: languageCode)
    }
}
