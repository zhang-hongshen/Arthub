//
//  MovieDetail.swift
//  Arthub
//
//  Created by 张鸿燊 on 17/2/2024.
//

import Foundation
import TMDb
import MediaPlayer

@Observable
class Movie: MediaItem, Identifiable, Hashable {
    let id: UUID
    var addedAt: Date?
    var metadata: TMDb.Movie
    var metrics: UserMetrics
    var posters: [ImageMetadata] = []
    var logos: [ImageMetadata] = []
    var backdrops: [ImageMetadata] = []
    var cast: [CastMember] = []
    var crew: [CrewMember] = []
    var videos: [VideoMetadata] = []
    
    init(fileURL: URL, duration: TimeInterval, addedAt: Date? = nil,
         metadata: TMDb.Movie, metrics: UserMetrics, id: UUID = UUID()) {
        self.id = id
        self.addedAt = addedAt
        self.metadata = metadata
        self.metrics = metrics
        super.init(fileURL: fileURL, duration: duration)
    }
    
    static func ==(lhs: Movie, rhs: Movie) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
}

extension Movie {
    var progress: Double {
        duration != 0 ? metrics.currentTime / duration : 0
    }

    /// What the player and the system's Now Playing panel show for this movie.
    func playlistItem() async -> PlaylistItem {
        var item = PlaylistItem(id: id.hashValue, url: fileURL, title: metadata.title)
        if let poster = metadata.posterPath {
            item.artwork = await MPMediaItemArtwork(contentsOf: poster)
        }
        return item
    }
}

extension Movie {
    static func examples() -> [Movie] {
        return [
            Movie(fileURL: URL(string: "")!,
                        duration: 10,
                  metadata: TMDb.Movie(id: 0, title: ""),
                        metrics: UserMetrics(.movie, tmdbID: 0))
        ]
    }
}

extension Movie {

    /// Cast, crew, images and videos from TMDb.
    func fetchRelatedData() async throws {
        let id = metadata.id
        async let images = ConfigurationService.shared.getImageConfiguration()
        async let credits = MovieService.shared.credits(forMovie: id)
        async let artwork = MovieService.shared.images(forMovie: id)
        async let videos = MovieService.shared.videos(forMovie: id)

        let config = try await images
        cast = try await credits.cast.map { $0.copy(profilePath: config.profileURL(for: $0.profilePath)) }
        crew = try await credits.crew.map { $0.copy(profilePath: config.profileURL(for: $0.profilePath)) }
        posters = try await artwork.posters.map { $0.copy(filePath: config.posterURL(for: $0.filePath)) }
        backdrops = try await artwork.backdrops.map { $0.copy(filePath: config.backdropURL(for: $0.filePath)) }
        logos = try await artwork.logos.map { $0.copy(filePath: config.posterURL(for: $0.filePath)) }
        self.videos = try await videos.results
    }
}
