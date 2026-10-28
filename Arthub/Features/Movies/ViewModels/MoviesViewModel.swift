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

@MainActor @Observable class MoviesViewModel {

    var movies: Set<Movie> = []
    var isFetchingData: Bool = false
    var searchText: String = ""
    /// Human-readable descriptions of what went wrong during the last scan.
    var scanErrors: [String] = []
    @ObservationIgnored var maxMoviePerSection = 10

    var filteredMovies: Set<Movie> {
        if searchText.isEmpty {
            return movies
        }
        return movies.filter {
            $0.metadata.title.localizedStandardContains(searchText)
                || $0.metadata.originalTitle?.localizedStandardContains(searchText) == true
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

    @ObservationIgnored private var fetchDataTask: Task<Void, Never>? = nil

    deinit {
        fetchDataTask?.cancel()
    }

    func fetchData() { fetchData(refreshLibrary: true) }

    func fetchData(refreshLibrary: Bool) {
        fetchDataTask?.cancel()
        isFetchingData = true
        fetchDataTask = Task {
            let library = LibraryViewModel.shared
            if refreshLibrary { await library.refresh() }
            guard !Task.isCancelled else { return }
            let previous = Dictionary(uniqueKeysWithValues: movies.map { ($0.id, $0) })
            let progress = WatchProgressStore.shared
            var result: Set<Movie> = []
            // Files matched to the same movie are its versions.
            let movieFiles = library.files.filter { $0.movie != nil }
            for files in Dictionary(grouping: movieFiles, by: { $0.movie!.id }).values {
                let files = files.sortedByQuality()
                let file = files.first(where: \.isAvailable) ?? files[0]
                guard let metadata = file.movieWithArtwork else { continue }
                let movie: Movie
                if let existing = files.lazy.compactMap({ previous[$0.id] }).first {
                    movie = existing
                    if movie.metadata.id != metadata.id {
                        movie.metrics = progress.metrics(.movie, tmdbID: metadata.id)
                        movie.cast = []; movie.crew = []; movie.posters = []
                        movie.backdrops = []; movie.logos = []; movie.videos = []
                    }
                    movie.metadata = metadata
                    movie.fileURL = file.fileURL
                    movie.duration = file.duration
                } else {
                    movie = Movie(fileURL: file.fileURL, duration: file.duration,
                                  addedAt: file.addedAt, metadata: metadata,
                                  metrics: progress.metrics(.movie, tmdbID: metadata.id), id: file.id)
                }
                movie.versions = files.filter(\.isAvailable).map(\.version)
                movie.isAvailable = file.isAvailable
                result.insert(movie)
            }
            let retained = Set(result.map(\.id))
            for movie in movies where !retained.contains(movie.id) { movie.isAvailable = false }
            movies = result
            scanErrors = library.scanErrors
            isFetchingData = false
        }
    }
}
