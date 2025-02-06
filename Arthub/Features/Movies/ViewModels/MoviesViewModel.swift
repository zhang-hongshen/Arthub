//
//  MoviesViewModel.swift
//  Arthub
//
//  Created by 张鸿燊 on 18/3/2024.
//

import Foundation
import AVFoundation
import OrderedCollections

import TMDb
import FeedKit

@Observable class MoviesViewModel {
    
    var movies: Set<Movie> = []
    var fetchDataTask: Task<Void, Error>? = nil
    var isFetchingData: Bool = false
    var searchText: String = ""
    @ObservationIgnored var maxMoviePerSection = 10
    
    var filteredMovies: Set<Movie> {
        if searchText.isEmpty {
            return movies
        }
        let search = searchText.lowercased()
        return movies.filter {
            if let originalTitle = $0.metadata.originalTitle,
                originalTitle.contains(search) {
                return true
            }
            return $0.metadata.title.lowercased().contains(search)
        }
    }
    
    var watchingMovies: [Movie] {
        filteredMovies.filter{ $0.metrics.watchedAt != nil }
            .sorted(using: KeyPathComparator(\.metrics.watchedAt, order: .reverse))
    }
    
    var recentlyAddedMovies: [Movie] {
        filteredMovies.sorted(using: KeyPathComparator(\.addedAt, order: .reverse))
    }
    
    var popularityMovies: [Movie] {
        filteredMovies.sorted(using: KeyPathComparator(\.metadata.popularity, order: .reverse))
    }
    
    var topRatedMovies: [Movie] {
        filteredMovies.sorted(using: KeyPathComparator(\.metadata.voteAverage, order: .reverse))
    }
    
    var groupedMovies: OrderedDictionary<String, [Movie]> {
        var res: OrderedDictionary<String, [Movie]> = [:]
        filteredMovies.forEach { movie in
            guard let genres = movie.metadata.genres else { return }
            genres.map{ $0.name }.forEach { genre in
                res.updateValue(forKey: genre, default: []) { $0.append(movie)}
            }
        }
        res.sort()
        return res
    }
    
    deinit {
        fetchDataTask?.cancel()
    }
    
    func fetchData() {
        if let fetchDataTask = fetchDataTask {
            fetchDataTask.cancel()
        }
        isFetchingData = true
        fetchDataTask = Task {
            let movies = try await self.fetchLocalData()
            DispatchQueue.main.async {
                self.movies = movies
                self.isFetchingData = false
            }
        }
    }
    
    private func fetchLocalData() async throws -> Set<Movie> {
        let urls = UserDefaults.standard.value(forKey: UserDefaults.library, default: [])
            .compactMap { URL(string: $0) }
        if urls.isEmpty { return [] }
        return try await withThrowingTaskGroup(of: Set<Movie>.self) { group in
            var movies: Set<Movie> = []
            for url in urls {
                group.addTask{ try await self.fetchDirectoryData(url) }
            }
            for try await result in group {
                movies.formUnion(result)
            }
            return movies
        }
    }
    
    private func fetchDirectoryData(_ dir: URL) async throws -> Set<Movie> {
        guard dir.hasDirectoryPath else { return [] }
        let urls = try FileManager.default
            .contentsOfDirectory(at: dir,
                                 includingPropertiesForKeys: nil,
                                 options: [.skipsHiddenFiles])
        var movies: Set<Movie> = []
        for url in urls {
            if url.hasDirectoryPath {
                movies.formUnion(try await fetchDirectoryData(url))
                continue
            }
            if !url.isVideo { continue }

            let movie = try await handleSingleMovie(url)
            if let movie = movie {
                movies.insert(movie)
            }
        }
        return movies
    }
    
    private func handleSingleMovie(_ url: URL) async throws -> Movie? {
        guard let matches = url.fileName.wholeMatch(of: RegexPattern.movieName) else { return nil }
        let title = String(matches.output.title)
        let year = Int(matches.output.year ?? "")
        let metadata = try await searchMovieMetadata(title: title, year: year)
        guard let metadata = metadata else {
            return nil
        }
        let metrics = try await UserMetrics.getByTMDbID(metadata.id)
        let duration = try await AVURLAsset(url: url).load(.duration).seconds
        return Movie(fileURL: url, duration: duration, addedAt: url.addedAt,
                     metadata: metadata, metrics: metrics)
    }

    
    private func searchMovieMetadata(title: String, year: Int?) async throws -> TMDb.Movie? {
        guard var metadata = try await SearchService.shared.searchMovies(query: title, year: year).results.first else {
            return nil
        }
        let imagesConfiguration = try await ConfigurationService.shared.getImageConfiguration()
        metadata = try await MovieService.shared.details(forMovie: metadata.id)
        return metadata.copy(
            posterPath: imagesConfiguration.posterURL(for: metadata.posterPath),
            backdropPath: imagesConfiguration.backdropURL(for: metadata.backdropPath)
        )
    }
    
}
