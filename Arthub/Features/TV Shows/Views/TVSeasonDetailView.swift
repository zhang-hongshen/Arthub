//
//  TVSeasonDetailView.swift
//  Arthub
//
//  Created by 张鸿燊 on 28/2/2024.
//

import SwiftUI
import MediaPlayer

struct TVSeasonDetailView: View {
    
    var season: TVSeasonDetail
    
    @State private var fetchDataTask: Task<Void, Error>? = nil
    @State private var setupPlayerTask: Task<Void, Error>? = nil
    @State private var columns: [GridItem] = []
    @State private var selectedTVEpisodeID: TVEpisodeDetail.ID? = nil
    @State private var playerPresented: Bool = false
    
    private var episodes: [TVEpisodeDetail] {
        season.episodes.sorted(using: KeyPathComparator(\.metadata.episodeNumber, order: .forward))
    }
    
    @Environment(ArthubVideoPlayer.self) private var player
    
    var body: some View {
        MainView()
            .frame(minWidth: Portrait.width())
            .toolbar{ ToolbarItems() }
            .task{ fetchData() }
            .refreshable { fetchData() }
            .navigationDestination(isPresented: $playerPresented) {
                TVShowPlayerView(playlist: episodes)
            }
            .onDisappear {
                fetchDataTask?.cancel()
                setupPlayerTask?.cancel()
            }
    }
}

// MARK: Toolbar

extension TVSeasonDetailView {
    
    @ToolbarContentBuilder
    func ToolbarItems() -> some ToolbarContent {
        ToolbarItemGroup {
            Button("Refresh", systemImage: "arrow.clockwise") {
                fetchData()
            }
        }
    }
}

extension TVSeasonDetailView {
    
    @ViewBuilder
    func MainView() -> some View {
        GeometryReader { proxy in
            ScrollView {
                let width = proxy.size.width
                ImageLoader(url: season.metadata.posterPath, 
                            aspectRatio: Landscape.aspectRatio)
                    .frame(width: width,
                           height: width / Landscape.aspectRatio)
                    .clipped()
                    .overlay(alignment: .bottomLeading) {
                        VStack(alignment: .leading) {
                            BackdropOverlayView().transparentEffect()
                                
                            Color.accent
                                .frame(width: width * season.progress,
                                       height: Default.cornerRadius)
                                       
                        }
                    }
                
                DetailView()
                    .safeAreaPadding()
            }
            .onChange(of: proxy.size.width, initial: true) { _, newValue in
                columns = Array(repeating: .init(.fixed(Portrait.width()), alignment: .top),
                                count: Int(newValue / Portrait.width()))
            }
        }
        
    }
}

// MARK: Backdrop Overlay

extension TVSeasonDetailView {
    
    @ViewBuilder
    func BackdropOverlayView() -> some View {
        VStack(alignment: .leading) {
            Text(verbatim: season.metadata.name)
                .font(.largeTitle.bold())
            
            HStack(alignment: .center) {
                if let airDate = season.metadata.airDate {
                    Text(airDate.formatted(.dateTime.day().month().year()))
                }
                
                Text(season.duration.formatted(unitsStyle: .full, zeroFormattingBehavior: .dropAll))
            }
            
        }
        .safeAreaPadding()
    }
}

extension TVSeasonDetailView {
    
    @ViewBuilder
    func DetailView() -> some View {
        VStack(alignment: .leading) {
            EpisodesSectionView()
            PostersSectionView()
        }
    }
    
}

// MARK: Posters Section

extension TVSeasonDetailView {
    @ViewBuilder
    func PostersSectionView() -> some View {
        
        Section {
            PostersView()
        } header: {
            Text("Posters")
                .font(.title.bold())
        }
    }
    
    @ViewBuilder
    func PostersView() -> some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top) {
                ForEach(season.posters) { poster in
                    ImageLoader(url: poster.filePath, aspectRatio: CGFloat(poster.aspectRatio))
                        .frame(width: Portrait.width(.small))
                        .shadow()
                        .cornerRadius()
                }
            }
        }
        .scrollIndicators(.visible)
    }
}

// MARK: Episode Section

extension TVSeasonDetailView {
    
    @ViewBuilder
    func EpisodesSectionView() -> some View {
        
        Section {
            EpisodesView()
        } header: {
            Text("Episodes")
                .font(.title.bold())
        }
    }
    
    @ViewBuilder
    func EpisodesView() -> some View {
        LazyVStack(alignment: .leading) {
            LazyVGrid(columns: columns,
                      alignment: .leading) {
                ForEach(episodes) { episode in
                    TVEpisodeCard(episode: episode, width: Portrait.width())
                        .onTapGesture {
                            selectedTVEpisodeID = episode.id
                            setupPlayer()
                        }
                }
            }
        }
        .focusEffect()
    }
    
}

extension TVSeasonDetailView {
    
    func fetchData() {
        fetchDataTask = Task {
            try await season.fetchRelatedData()
        }
    }
    
    func setupPlayer() {
        guard let index = episodes.firstIndex(where: { $0.id == selectedTVEpisodeID }) else {
            return
        }
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
