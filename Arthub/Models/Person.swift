//
//  Person.swift
//  Arthub
//
//  Created by 张鸿燊 on 20/2/2024.
//

import Foundation
import TMDb

@Observable
class Person: Identifiable, Hashable {
    var id: TMDb.Person.ID { metadata.id }
    var metadata: TMDb.Person
    var castMovies: [TMDb.Movie] = []
    var knownForMovies: [TMDb.Movie] = []
    var profiles: [ImageMetadata] = []
    
    init(metadata: TMDb.Person) {
        self.metadata = metadata
    }
    
    static func==(lhs: Person, rhs: Person) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension Person {

    func fetchDetail() async throws {
        async let images = ConfigurationService.shared.getImageConfiguration()
        async let details = PersonService.shared.details(forPerson: metadata.id)
        let config = try await images
        let metadata = try await details
        self.metadata = metadata.copy(profilePath: config.profileURL(for: metadata.profilePath))
    }

    /// Movies, known-for movies and profile pictures from TMDb.
    func fetchRelatedData() async throws {
        let id = metadata.id
        async let images = ConfigurationService.shared.getImageConfiguration()
        async let credits = PersonService.shared.movieCredits(forPerson: id)
        async let knownFor = PersonService.shared.knownFor(forPerson: id)
        async let pictures = PersonService.shared.images(forPerson: id)

        let config = try await images
        func withImages(_ movie: TMDb.Movie) -> TMDb.Movie {
            movie.copy(posterPath: config.posterURL(for: movie.posterPath),
                       backdropPath: config.backdropURL(for: movie.backdropPath))
        }
        castMovies = try await credits.cast.map(withImages)
        knownForMovies = try await knownFor.compactMap { show -> TMDb.Movie? in
            guard case .movie(let movie) = show else { return nil }
            return withImages(movie)
        }
        profiles = try await pictures.profiles.map { $0.copy(filePath: config.profileURL(for: $0.filePath)) }
    }
}
