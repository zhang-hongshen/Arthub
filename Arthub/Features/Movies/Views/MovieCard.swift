//
//  MovieCard.swift
//  Arthub
//
//  Created by 张鸿燊 on 31/1/2024.
//

import SwiftUI
import MediaPlayer

struct MovieCard: View {
    
    @State var movie: MovieDetail
    @State var width: CGFloat
    
    @State private var isHovering = false
    @State private var playerPresented: Bool = false
    @State private var fetchDataTask: Task<Void, Error>? = nil
    @State private var setupPlayerTask: Task<Void, Error>? = nil
    @State private var sheetPreseted = false
    
    @Environment(ArthubVideoPlayer.self) private var player: ArthubVideoPlayer
    
    var body: some View {
        VStack(alignment: .leading) {
            
            MoviePosterView()
            
            Text(movie.metadata.title).font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if let releaseDate = movie.metadata.releaseDate {
                Text(releaseDate.formatted(.dateTime.year())).font(.subheadline)
            }
            
        }
        .frame(width: width)
        .navigationDestination(isPresented: $playerPresented) {
            MoviePlayerView(metrics: movie.metrics)
                .navigationTitle(movie.metadata.title)
        }
        .sheet(isPresented: $sheetPreseted) {
            MovieMetadataSearchView(movie: movie)
        }
    }
    
}

extension MovieCard {
    
    @ViewBuilder
    func MoviePosterView() -> some View {
        ImageLoader(url: movie.metadata.posterPath,
                    aspectRatio: Portrait.aspectRatio) {
            ImageButton(systemImage: "film")
        }
        .frame(width: width, height: width / Portrait.aspectRatio)
        .overlay(alignment: .bottomLeading) {
            MoviePosterOverlay()
        }
        .shadow()
        .cornerRadius()
        .onHover(perform: { isHovering = $0 })
        .contextMenu { MoviePosterContextMenu() }
    }
    
    @ViewBuilder
    func MoviePosterContextMenu() -> some View {
        Button("Play", systemImage: "play.fill", action: setupPlayer)
        Button("Edit Metadata", systemImage: "square.and.pencil", action: { sheetPreseted = true})
        ShareLink(item: movie.fileURL,
                  subject: Text(verbatim: movie.metadata.title),
                  message: Text(verbatim: movie.metadata.overview ?? "" )) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
    }
    
    
    @ViewBuilder
    func MoviePosterOverlay() -> some View {
        ZStack(alignment: .bottomLeading) {
            Color.accent
                .frame(width: width * movie.progress,
                       height: Default.cornerRadius)
            if isHovering {
                ImageButton(systemImage: "play.fill", action: setupPlayer)
            }
        }
    }
}

extension MovieCard {
    
    func setupPlayer() {
        setupPlayerTask = Task {
            var artwork: MPMediaItemArtwork? = nil
            if let cover = movie.metadata.posterPath {
                artwork = await MPMediaItemArtwork(contentsOf: cover)
            }
            let metadata = NowPlayableStaticMetadata(
                id: NSNumber(value: movie.id.hashValue),
                assetURL: movie.fileURL, mediaType: .video,
                isLiveStream: false,
                title: movie.metadata.title,
                artwork: artwork)
            player.preloadItems(playableAssets: [metadata])
            playerPresented = true
        }
    }
}

#Preview {
    MovieCard(movie: MovieDetail.examples()[0], width: 200)
}
