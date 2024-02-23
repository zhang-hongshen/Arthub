//
//  PersonDetail.swift
//  Arthub
//
//  Created by 张鸿燊 on 20/2/2024.
//

import Foundation
import TMDb

class PersonDetail: Identifiable {
    let id = UUID()
    var info: Person
    var castMovies: [Movie] = []
    var knownForMovies: [Movie] = []
    var profiles: [ImageMetadata] = []
    
    init(info: Person) {
        self.info = info
    }
}

extension PersonDetail: Equatable {
    static func==(lhs: PersonDetail, rhs: PersonDetail) -> Bool {
        return lhs.id == rhs.id
    }
}

extension PersonDetail {
    
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
        async let fetchMovieCredits = PersonService.shared.movieCredits(forPerson: info.id)
        let (imageConfiguration, movieCredits) = try await (getImageConfiguration, fetchMovieCredits)
        movieCredits.cast.forEach { cast in
            self.castMovies.append(cast.copy(
                posterPath:imageConfiguration.posterURL(for: cast.posterPath),
                backdropPath: imageConfiguration.backdropURL(for: cast.backdropPath)
            ))
        }
    }
    
    func fetchKnownFor() async throws {
        async let getImageConfiguration = ConfigurationService.shared.getImageConfiguration()
        async let fetchKnownFor = PersonService.shared.knownFor(forPerson: info.id)
        let (imageConfiguration, knownFor) = try await (getImageConfiguration, fetchKnownFor)
        knownFor.forEach { show in
            switch show {
            case .movie(let movie):
                self.knownForMovies.append(movie.copy(
                    posterPath: imageConfiguration.posterURL(for: movie.posterPath),
                    backdropPath: imageConfiguration.backdropURL(for: movie.backdropPath)
                ))
            case .tvSeries(let tvSeries):
               break
            }
        }
    }
    
    func fetchProfiles() async throws {
        async let getImageConfiguration = ConfigurationService.shared.getImageConfiguration()
        async let fetchImages = PersonService.shared.images(forPerson: info.id)
        let (imageConfiguration, images) = try await (getImageConfiguration, fetchImages)
        images.profiles.forEach { profile in
            self.profiles.append(profile.copy(
                filePath: imageConfiguration.profileURL(for: profile.filePath)
            ))
        }
    }
}
