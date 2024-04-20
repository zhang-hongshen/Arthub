//
//  TVSeasonCardView.swift
//  Arthub
//
//  Created by 张鸿燊 on 28/2/2024.
//

import SwiftUI
import MediaPlayer

struct TVSeasonCardView: View {
    
    var season: TVSeasonDetail
    
    @State var height: CGFloat
    @State private var isHovering = false
    @State private var setupPlayerTask: Task<Void, Error>? = nil
    @State private var playerPresented: Bool = false
    
    @Environment(ArthubVideoPlayer.self) private var player: ArthubVideoPlayer
    
    private var episodes: [TVEpisodeDetail] {
        season.episodes.sorted(using: KeyPathComparator(\.metadata.episodeNumber, order: .forward))
    }
    
    var body: some View {
        HStack(alignment: .center) {
            
            TVSeasonPosterView()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Season \(season.metadata.seasonNumber)")
                    .font(.title2.bold())
                
                HStack(alignment: .center) {
                    Text("\(season.episodes.count) Episode")
                    Text(season.metadata.airDate?.formatted(date: .abbreviated, time: .omitted) ?? "")
                }
                .font(.title3)
                
                Text(season.metadata.overview ?? "").font(.body)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .frame(height: height)
        .transparentEffect()
        .cornerRadius()
        .task { await fetchData() }
        .navigationDestination(isPresented: $playerPresented) {
            TVShowPlayerView(playlist: episodes)
        }
    }
}

extension TVSeasonCardView {
    
    @ViewBuilder
    func TVSeasonPosterView() -> some View {
        ImageLoader(url: season.metadata.posterPath, aspectRatio: Portrait.aspectRatio) {
            ImageButton(systemImage: "photo.stack")
        }
        .frame(width: height * Portrait.aspectRatio, height: height)
        .clipped()
        .overlay(alignment: .bottomLeading) {
            TVSeasonPosterOverlay()
        }
        .shadow()
        .cornerRadius()
        .onHover(perform: { isHovering = $0 })
        .contextMenu {
            Button(action: setupPlayer) {
                Label("Play", systemImage: "play.fill")
            }
        }
    }
    
    @ViewBuilder
    func TVSeasonPosterOverlay() -> some View {
        ZStack(alignment: .bottomLeading) {
            Color.accent
                .frame(width: height * Portrait.aspectRatio * season.progress,
                       height: Default.cornerRadius)
            if isHovering {
                ImageButton(systemImage: "play.fill", action: setupPlayer)
            }
        }
    }
}

extension TVSeasonCardView {
    
    func fetchData() async  {
        do { try await season.fetchDetail()}
        catch {}
    }
    
    func setupPlayer() {
        guard !episodes.isEmpty else { return }
        guard let episode = season.lastWatchingEpisode else { return }
        let index = episodes.firstIndex(where: { $0.id == episode.id }) ?? episodes.startIndex
        setupPlayerTask = Task {
            var playableAssets: [NowPlayableStaticMetadata] = []
            
            for episode in episodes[index...] + episodes[0...index] {
                var artwork: MPMediaItemArtwork?  = nil
                if let still = episode.metadata.stillPath {
                    artwork = await MPMediaItemArtwork(contentsOf: still)
                }
                playableAssets.append(NowPlayableStaticMetadata(
                    id: NSNumber(value: episode.id.hashValue),
                    assetURL: episode.fileURL, mediaType: .video,
                    isLiveStream: false, title: episode.metadata.name,
                    artwork: artwork))
            }
            player.preloadItems(playableAssets: playableAssets)
            playerPresented = true
        }
    }
}

