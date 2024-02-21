//
//  MovieDetail.swift
//  Arthub
//
//  Created by 张鸿燊 on 17/2/2024.
//

import Foundation
import TMDb

enum MovieOrderProperty: String, CaseIterable, Identifiable {
    case title, releaseDate, createdAt, watchedAt
    var id: Self { self }
}

enum MovieGroup: String, CaseIterable, Identifiable {
    case none, releaseYear
    var id: Self { self }
}

class MovieDetail: Identifiable {
    let id = UUID()
    public var urls: [URL]
    public var metadata: Movie
    public var metrics: MovieMetrics
    public var posters: [ImageMetadata] = []
    public var logos: [ImageMetadata] = []
    public var backdrops: [ImageMetadata] = []
    public var cast: [CastMember] = []
    public var crew: [CrewMember] = []
    public var videos: [VideoMetadata] = []
    
    init(urls: [URL] = [], metadata: Movie, metrics: MovieMetrics) {
        self.urls = urls
        self.metadata = metadata
        self.metrics = metrics
        
    }
}

extension MovieDetail: Equatable {
    static func ==(lhs: MovieDetail, rhs: MovieDetail) -> Bool {
        return lhs.id == rhs.id
    }
}

extension MovieDetail {
    static func examples() -> [MovieDetail] {
        return [
            MovieDetail(urls: [], 
                        metadata: Movie(id: 0, title: ""),
                        metrics: MovieMetrics())
        ]
    }
}

extension MovieDetail {
    
    func fetchDetail() async throws{
        async let getImageConfiguration = ConfigurationService.shared.getImageConfiguration()
        async let getMetadata = MovieService.shared.details(forMovie: metadata.id)
        let (imagesConfiguration, metadata) = try await(getImageConfiguration, getMetadata)
        self.metadata = metadata.copy(
            posterPath: imagesConfiguration.posterURL(for: metadata.posterPath),
            backdropPath: imagesConfiguration.backdropURL(for: metadata.backdropPath)
        )
    }
    
    func fetchRelatedData() async throws {
        async let fetchCredits: () = self.fetchCredits()
        async let fetchImages: () = self.fetchImages()
        try await (fetchCredits, fetchImages)
    }
    
    func fetchCredits() async throws  {
        if !self.cast.isEmpty || !self.crew.isEmpty {
            return
        }
        async let getImageConfiguration = ConfigurationService.shared.getImageConfiguration()
        async let fetchCredits = try await MovieService.shared.credits(forMovie: metadata.id)
        let (imagesConfiguration, credits) = try await(getImageConfiguration, fetchCredits)
        
        await withTaskGroup(of: Void.self) { group in
            
            group.addTask {
                for castMember in credits.cast {
                    self.cast.append(castMember.copy(
                        profilePath: imagesConfiguration.profileURL(for: castMember.profilePath)))
                }
            }
            
            group.addTask {
                for crewMember in credits.crew {
                    self.crew.append(crewMember.copy(
                        profilePath: imagesConfiguration.profileURL(for: crewMember.profilePath)))
                }
            }
        }
    }
    
    func fetchImages() async throws  {
        if !self.posters.isEmpty
            || !self.backdrops.isEmpty
            || !self.logos.isEmpty{
            return
        }
        async let getImageConfiguration = ConfigurationService.shared.getImageConfiguration()
        async let fetchImages = MovieService.shared.images(forMovie: metadata.id)
        let (imagesConfiguration, images) = try await(getImageConfiguration, fetchImages)
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for poster in images.posters{
                    self.posters.append(poster.copy(filePath: imagesConfiguration.posterURL(for: poster.filePath)))
                }
            }
            
            group.addTask {
                for backdrop in images.backdrops{
                    self.backdrops.append(backdrop.copy(filePath: imagesConfiguration.backdropURL(for: backdrop.filePath)))
                }
            }
            
            group.addTask {
                for logo in images.logos {
                    self.logos.append(logo.copy(filePath: imagesConfiguration.posterURL(for: logo.filePath)))
                }
            }
        }
    }
    
    func fetchVideos() async throws  {
        if !videos.isEmpty {
            return
        }
        self.videos = try await MovieService.shared.videos(forMovie: metadata.id).results
    }
}
