//
//  MovieMetadataSearchView.swift
//  Arthub
//
//  Created by 张鸿燊 on 18/3/2024.
//

import SwiftUI
import TMDb

struct MovieMetadataSearchView: View {
    
    @Bindable var movie: MovieDetail
    
    @State private var fetchDataTask: Task<Void, Error>? = nil
    @State private var movieMetadata: [TMDb.Movie] =  []

    var body: some View {
        VStack(alignment: .center) {
            
            Text(verbatim: movie.metadata.title).lineLimit(1)
                .font(.headline)
            
            ScrollView {
                ForEach(movieMetadata) { metadata in
                    MovieCard(metadata)
                        .onTapGesture { movie.metadata = metadata }
                }
            }
            .scrollIndicators(.never, axes: .vertical)
            .frame(height: 400)
        }
        .safeAreaPadding()
        .frame(width: 400)
        .task { fetchData() }
    }
}

extension MovieMetadataSearchView {
    
    @ViewBuilder
    func MovieCard(_ metadata: TMDb.Movie) -> some View {
        HStack(alignment: .center) {
            
            MoviePoster(metadata.posterPath)
            
            VStack(alignment: .leading) {
                Group {
                    Text(metadata.title).font(.headline)
                    if let releaseDate = metadata.releaseDate {
                        Text(releaseDate.formatted(.dateTime.year()))
                            .font(.subheadline)
                    }
                    Text(metadata.overview ?? "").font(.caption)
                }
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            }
            .padding(.trailing)
            
            Spacer()
        }
        .overlay(alignment: .topTrailing) {
            if metadata.id == movie.id {
                Image(systemName: "checkmark.circle")
                    .imageScale(.large)
            }
        }
        .transparentEffect()
        .cornerRadius()
    }
    
    @ViewBuilder
    func MoviePoster(_ url: URL?) -> some View {
        ImageLoader(url: url,
                    aspectRatio: Portrait.aspectRatio,
                    contentMode: .fit)
            .frame(height: 100)
            .shadow()
            .cornerRadius()
    }
}

extension MovieMetadataSearchView {
    
    func fetchData() {
        fetchDataTask?.cancel()
        fetchDataTask = Task {
            var year: Int? {
                guard let releaseDate =  movie.metadata.releaseDate else { return nil }
                return Calendar.current.component(.year, from: releaseDate)
            }
            let imagesConfiguration = try await ConfigurationService.shared.getImageConfiguration()
            let movieMetadata = try await SearchService.shared.searchMovies(query: movie.metadata.title, page: 1).results
            movieMetadata.forEach { metadata in
                self.movieMetadata.append(metadata.copy(
                    posterPath: imagesConfiguration.posterURL(for: metadata.posterPath),
                    backdropPath: imagesConfiguration.backdropURL(for: metadata.backdropPath)
                ))
            }
        }
    }
}
