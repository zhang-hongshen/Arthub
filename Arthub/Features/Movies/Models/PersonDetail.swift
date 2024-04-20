//
//  PersonDetail.swift
//  Arthub
//
//  Created by 张鸿燊 on 20/2/2024.
//

import Foundation
import TMDb

@Observable
class PersonDetail: Identifiable, Hashable {
    var id: Person.ID { metadata.id }
    var metadata: Person
    var castMovies: [Movie] = []
    var knownForMovies: [Movie] = []
    var profiles: [ImageMetadata] = []
    
    init(metadata: Person) {
        self.metadata = metadata
    }
    
    static func==(lhs: PersonDetail, rhs: PersonDetail) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension PersonDetail {
    
    func fetchDetail() async throws {
        async let getImageConfiguration = ConfigurationService.shared.getImageConfiguration()
        async let fetchDetail = PersonService.shared.details(forPerson: metadata.id)
        let (imageConfiguration, metadata) =  try await (getImageConfiguration, fetchDetail)
        self.metadata = metadata.copy(
            profilePath: imageConfiguration.profileURL(for: metadata.profilePath)
        )
    }
    
    func fetchRelatedData() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await self.fetchCastMovies() }
            group.addTask { try await self.fetchKnownFor() }
            group.addTask { try await self.fetchProfiles() }
            try await group.waitForAll()
        }
    }
    
    func fetchCastMovies() async throws {
        async let getImageConfiguration = ConfigurationService.shared.getImageConfiguration()
        async let fetchMovieCredits = PersonService.shared.movieCredits(forPerson: metadata.id)
        let (imageConfiguration, movieCredits) = try await (getImageConfiguration, fetchMovieCredits)
        var castMovies: [Movie] = []
        movieCredits.cast.forEach { cast in
            castMovies.append(cast.copy(
                posterPath:imageConfiguration.posterURL(for: cast.posterPath),
                backdropPath: imageConfiguration.backdropURL(for: cast.backdropPath)
            ))
        }
        self.castMovies = castMovies
    }
    
    func fetchKnownFor() async throws {
        async let getImageConfiguration = ConfigurationService.shared.getImageConfiguration()
        async let fetchKnownFor = PersonService.shared.knownFor(forPerson: metadata.id)
        let (imageConfiguration, knownFor) = try await (getImageConfiguration, fetchKnownFor)
        var knownForMovies: [Movie] = []
        knownFor.forEach { show in
            switch show {
            case .movie(let movie):
                knownForMovies.append(movie.copy(
                    posterPath: imageConfiguration.posterURL(for: movie.posterPath),
                    backdropPath: imageConfiguration.backdropURL(for: movie.backdropPath)
                ))
            case .tvSeries(let tvSeries):
               break
            }
        }
        self.knownForMovies = knownForMovies
    }
    
    func fetchProfiles() async throws {
        async let getImageConfiguration = ConfigurationService.shared.getImageConfiguration()
        async let fetchImages = PersonService.shared.images(forPerson: metadata.id)
        let (imageConfiguration, images) = try await (getImageConfiguration, fetchImages)
        var profiles: [ImageMetadata] = []
        images.profiles.forEach { profile in
            profiles.append(profile.copy(
                filePath: imageConfiguration.profileURL(for: profile.filePath)
            ))
        }
        self.profiles = profiles
    }
}
