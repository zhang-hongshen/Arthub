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
    
    var movies: Set<MovieDetail> = []
    var fetchDataTask: Task<Void, Error>? = nil
    var isFetchingData: Bool = false
    var searchText: String = ""
    @ObservationIgnored var sectionMaxMovie = 10
    
    var filteredMovies: Set<MovieDetail> {
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
    
    var watchingMovies: [MovieDetail] {
        filteredMovies.filter{ $0.metrics.watchedAt != nil }
            .sorted(using: KeyPathComparator(\.metrics.watchedAt, order: .reverse))
    }
    
    var recentlyAddedMovies: [MovieDetail] {
        filteredMovies.sorted(using: KeyPathComparator(\.addedAt, order: .reverse))
    }
    
    var popularityMovies: [MovieDetail] {
        filteredMovies.sorted(using: KeyPathComparator(\.metadata.popularity, order: .reverse))
    }
    
    var topRatedMovies: [MovieDetail] {
        filteredMovies.sorted(using: KeyPathComparator(\.metadata.voteAverage, order: .reverse))
    }
    
    var groupedMovies: OrderedDictionary<String, [MovieDetail]> {
        var res: OrderedDictionary<String, [MovieDetail]> = [:]
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
        isFetchingData = true
        fetchDataTask?.cancel()
        fetchDataTask = Task {
            let movies = try await withThrowingTaskGroup(of: Set<MovieDetail>.self) { group in
                var movies: Set<MovieDetail> = []
                group.addTask{ try await self.fetchLocalData() }
                group.addTask{ try await self.fetchFeedData() }
                for try await result in group {
                    movies.formUnion(result)
                }
                return movies
            }
            DispatchQueue.main.async {
                self.movies.formUnion(movies)
                // delete not exist element
                self.movies.formIntersection(movies)
                self.isFetchingData = false
            }
        }
    }
    
    private func fetchLocalData() async throws -> Set<MovieDetail> {
        let urls = UserDefaults.standard.value(forKey: UserDefaults.localMoviesData, default: [])
            .compactMap { URL(string: $0) }
        return try await fetchMultiDirectoryData(urls)
    }
    
    private func fetchMultiDirectoryData(_ urls: [URL]) async throws  -> Set<MovieDetail> {
        if urls.isEmpty { return [] }
        return try await withThrowingTaskGroup(of: Set<MovieDetail>.self) { group in
            var movies: Set<MovieDetail> = []
            for url in urls {
                group.addTask{ try await self.fetchDirectoryData(url) }
            }
            for try await result in group {
                movies.formUnion(result)
            }
            return movies
        }
    }
    
    private func fetchDirectoryData(_ dir: URL) async throws -> Set<MovieDetail> {
        guard dir.hasDirectoryPath else { return [] }
        let urls = try FileManager.default
            .contentsOfDirectory(at: dir,
                                 includingPropertiesForKeys: nil,
                                 options: [.skipsHiddenFiles])
        var movies: Set<MovieDetail> = []
        for url in urls {
            if url.hasDirectoryPath {
                movies.formUnion(try await fetchDirectoryData(url))
                continue
            }
            if !url.isVideo { continue }
            guard let matches = url.fileName.wholeMatch(of: RegexPattern.movieName) else { continue }
            let title = String(matches.output.title)
            let year = Int(matches.output.year ?? "")
            
            let metadata = try await searchMovieMetadata(title: title, year: year)
            let metrics = try await UserMetrics.getByTMDbID(metadata.id)
            let duration = try await AVURLAsset(url: url).load(.duration).seconds
            let movie = MovieDetail(fileURL: url, duration: duration, addedAt: url.addedAt,
                                    metadata: metadata, metrics: metrics)
            movies.insert(movie)
        }
        return movies
    }

    private func searchMovieMetadata(title: String, year: Int?) async throws -> Movie {
        guard var metadata = try await SearchService.shared.searchMovies(query: title, year: year).results.first else {
            return Movie(id: UUID().hashValue, title: title,
                         releaseDate: Calendar.current.date(from: DateComponents(year: year)))
        }
        let imagesConfiguration = try await ConfigurationService.shared.getImageConfiguration()
        metadata = try await MovieService.shared.details(forMovie: metadata.id)
        return metadata.copy(
            posterPath: imagesConfiguration.posterURL(for: metadata.posterPath),
            backdropPath: imagesConfiguration.backdropURL(for: metadata.backdropPath)
        )
    }
    
    private func fetchFeedData() async throws -> Set<MovieDetail> {
        var movies: Set<MovieDetail> = []
        for feed in try await FeedDetail.listAll() {
            guard let url = URL(string: feed.url) else { continue }
            let res = FeedParser(URL: url).parse()
            switch res {
            case .success(let feed):
                movies.formUnion(try await handleFeed(feed))
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
        return movies
    }
    
    private func handleFeed(_ feed: Feed) async throws -> Set<MovieDetail> {
        var movies: Set<MovieDetail> = []
        if let json = feed.jsonFeed {
            movies.formUnion(try await handleJSONFeed(json))
        }
        if let rss = feed.rssFeed {
            movies.formUnion(try await handleRSSFeed(rss))
        }
        return movies
    }
    
    private func handleJSONFeed(_ feed: JSONFeed) async throws -> Set<MovieDetail> {
        guard let items = feed.items else { return []}
        var movies: Set<MovieDetail> = []
        for item in items {
            print("title: \(item.title ?? ""), url: \(item.url ?? ""), externalUrl: \(item.externalUrl ?? "")")
            guard let urlString = item.url, let url = URL(string: urlString),
                  let title = item.title else { continue }
            var year: Int? {
                guard let date = item.datePublished else { return nil }
                return Calendar.current.component(.year, from: date)
            }
            let metadata = try await searchMovieMetadata(title: title, year: year)
            let metrics = try await UserMetrics.getByTMDbID(metadata.id)
            let movie = MovieDetail(fileURL: url, duration: 0,
                                    metadata: metadata, metrics: metrics)
            movies.insert(movie)
            self.movies.insert(movie)
        }
        return movies
    }
    
    private func handleRSSFeed(_ feed: RSSFeed) async throws -> Set<MovieDetail> {
        guard let items = feed.items else { return [] }
        var movies: Set<MovieDetail> = []
        for item in items {
            print("title: \(item.title ?? ""), url: \(item.link ?? "")")
            guard let urlString = item.link, let url = URL(string: urlString),
                  let title = item.title else { continue }
            var year: Int? {
                guard let date = item.pubDate else { return nil }
                return Calendar.current.component(.year, from: date)
            }
            let metadata = try await searchMovieMetadata(title: title, year: year)
            let metrics = try await UserMetrics.getByTMDbID(metadata.id)
            let movie = MovieDetail(fileURL: url, duration: 0,
                                    metadata: metadata, metrics: metrics)
            movies.insert(movie)
            self.movies.insert(movie)
        }
        return movies
    }
}
