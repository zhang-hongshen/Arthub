//
//  MovieDetail.swift
//  Arthub
//
//  Created by 张鸿燊 on 17/2/2024.
//

import Foundation
import TMDb

@Observable
class MovieDetail: MediaItem, Identifiable, Hashable {
    var id: Movie.ID { metadata.id }
    var addedAt: Date?
    var metadata: Movie 
    var metrics: UserMetrics
    var posters: [ImageMetadata] = []
    var logos: [ImageMetadata] = []
    var backdrops: [ImageMetadata] = []
    var cast: [CastMember] = []
    var crew: [CrewMember] = []
    var videos: [VideoMetadata] = []
    
    init(fileURL: URL, duration: TimeInterval, addedAt: Date? = nil,
         metadata: Movie, metrics: UserMetrics = UserMetrics()) {
        self.addedAt = addedAt
        self.metadata = metadata
        self.metrics = metrics
        super.init(fileURL: fileURL, duration: duration)
    }
    
    static func ==(lhs: MovieDetail, rhs: MovieDetail) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
}

extension MovieDetail {
    var progress: Double {
        return duration != 0 ? Double(metrics.currentTime) / Double(duration) : 0
    }
}

extension MovieDetail {
    static func examples() -> [MovieDetail] {
        return [
            MovieDetail(fileURL: URL(string: "")!,
                        duration: 10,
                        metadata: Movie(id: 0, title: ""),
                        metrics: UserMetrics())
        ]
    }
}

extension MovieDetail {
    
    func fetchRelatedData() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask{ try await self.fetchCredits() }
            group.addTask{ try await self.fetchImages() }
            group.addTask{ try await self.fetchVideos() }
            try await group.waitForAll()
        }
    }
    
    func fetchCredits() async throws  {
        async let getImageConfiguration = ConfigurationService.shared.getImageConfiguration()
        async let fetchCredits = try await MovieService.shared.credits(forMovie: metadata.id)
        let (imagesConfiguration, credits) = try await(getImageConfiguration, fetchCredits)
        
        await withTaskGroup(of: Void.self) { group in
            
            group.addTask {
                var cast: [CastMember] =  []
                for castMember in credits.cast {
                    cast.append(castMember.copy(
                        profilePath: imagesConfiguration.profileURL(for: castMember.profilePath)))
                }
                self.cast = cast
            }
            
            group.addTask {
                var crew: [CrewMember] =  []
                for crewMember in credits.crew {
                    crew.append(crewMember.copy(
                        profilePath: imagesConfiguration.profileURL(for: crewMember.profilePath)))
                }
                self.crew = crew
            }
            await group.waitForAll()
        }
    }
    
    func fetchImages() async throws  {
        async let getImageConfiguration = ConfigurationService.shared.getImageConfiguration()
        async let fetchImages = MovieService.shared.images(forMovie: metadata.id)
        let (imagesConfiguration, images) = try await(getImageConfiguration, fetchImages)
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                var posters: [ImageMetadata] =  []
                for poster in images.posters{
                    posters.append(poster.copy(filePath: imagesConfiguration.posterURL(for: poster.filePath)))
                }
                self.posters = posters
            }
            
            group.addTask {
                var backdrops: [ImageMetadata] =  []
                for backdrop in images.backdrops{
                    backdrops.append(backdrop.copy(filePath: imagesConfiguration.backdropURL(for: backdrop.filePath)))
                }
                self.backdrops = backdrops
            }
            
            group.addTask {
                var logos: [ImageMetadata] =  []
                for logo in images.logos {
                    logos.append(logo.copy(filePath: imagesConfiguration.posterURL(for: logo.filePath)))
                }
                self.logos = logos
            }
            
            await group.waitForAll()
        }
    }
    
    func fetchVideos() async throws  {
        self.videos = try await MovieService.shared.videos(forMovie: metadata.id).results
    }
    
}
