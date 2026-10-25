//
//  TVSeasonDetailView.swift
//  Arthub
//
//  Created by 张鸿燊 on 28/2/2024.
//

import SwiftUI

struct TVSeasonDetailView: View {
    
    var season: TVSeasonDetail
    
    @State private var fetchDataTask: Task<Void, Error>? = nil
    @State private var setupPlayerTask: Task<Void, Error>? = nil
    @State private var playerPresented: Bool = false
    @State private var playerStartIndex: Int = 0

    private var episodes: [TVEpisodeDetail] {
        season.episodes.sorted(using: KeyPathComparator(\.metadata.episodeNumber, order: .forward))
    }
    
    private var availableEpisodes: [TVEpisodeDetail] {
        episodes.filter(\.isAvailable)
    }
    
    private var lastWatchingEpisode: TVEpisodeDetail? {
        availableEpisodes.filter { $0.metrics.watchedAt != nil }
            .sorted(using: KeyPathComparator(\.metrics.watchedAt, order: .reverse))
            .first
    }

    @Environment(ArthubVideoPlayer.self) private var player

    var body: some View {
        MainView()
            .frame(minWidth: Portrait.width())
            .toolbar{ ToolbarItems() }
            .task{ fetchData() }
            .refreshable { fetchData() }
            .navigationDestination(isPresented: $playerPresented) {
                TVShowPlayerView(playlist: availableEpisodes, startAtIndex: playerStartIndex)
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
        MediaDetailPage { size in
            HeaderView(size: size)
        } content: {
            EpisodesSectionView()
            PostersSectionView()
        }
    }
}

// MARK: Header

extension TVSeasonDetailView {
    
    /// Poster beside the title, over a blurred copy of the poster.
    @ViewBuilder
    func HeaderView(size: CGSize) -> some View {
        let posterWidth: CGFloat = size.width >= 720 ? 240 : 160
        let isWide = size.width >= 560
        let layout = isWide
            ? AnyLayout(HStackLayout(alignment: .bottom, spacing: 32))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 20))
        
        layout {
            ArtworkImage(url: season.metadata.posterPath, aspectRatio: Portrait.aspectRatio) {
                ImageButton(systemImage: "photo.stack")
            }
            .frame(width: posterWidth, height: posterWidth / Portrait.aspectRatio)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(radius: 20)
            
            InfoView()
                .frame(maxWidth: 560, alignment: .leading)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, MediaDetail.horizontalPadding)
        .padding(.top, 60)
        .padding(.bottom, 8)
        .frame(width: size.width, alignment: .leading)
        .background {
            ArtworkImage(url: season.metadata.posterPath) {
                MediaDetail.background
            }
            .frame(width: size.width)
            .blur(radius: 60)
            .opacity(0.6)
            .overlay {
                LinearGradient(colors: [.clear, MediaDetail.background],
                               startPoint: .top, endPoint: .bottom)
            }
            .clipped()
        }
    }
    
    @ViewBuilder
    func InfoView() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            MediaTitleText(title: season.metadata.name)
            
            MediaMetadataLine(items: [
                season.metadata.airDate?.formatted(.dateTime.year()) ?? "",
                String(localized: "\(season.episodes.count) Episodes"),
                season.duration > 0 ? MediaDetail.runtime(season.duration) : "",
            ])
            
            if let overview = season.metadata.overview, !overview.isEmpty {
                Text(verbatim: overview)
                    .font(.body)
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Button {
                let episode = lastWatchingEpisode ?? availableEpisodes.first
                setupPlayer(selected: episode)
            } label: {
                if let episode = lastWatchingEpisode {
                    Label("Resume E\(episode.metadata.episodeNumber)", systemImage: "play.fill")
                } else {
                    Label("Play", systemImage: "play.fill")
                }
            }
            .buttonStyle(MediaPlayButtonStyle())
            .disabled(availableEpisodes.isEmpty)
            
            if let episode = lastWatchingEpisode {
                MediaRemainingView(progress: episode.progress, duration: episode.duration)
            }
        }
    }
}

// MARK: Episode Section

extension TVSeasonDetailView {
    
    @ViewBuilder
    func EpisodesSectionView() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            MediaSectionHeader(title: "Episodes")
            
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(episodes) { episode in
                    TVEpisodeCard(episode: episode, width: 280, axis: .horizontal, onPlay: {
                        guard episode.isAvailable else { return }
                        setupPlayer(selected: episode)
                    })
                    if episode.id != episodes.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(.horizontal, MediaDetail.horizontalPadding)
    }
    
}

// MARK: Posters Section

extension TVSeasonDetailView {
    
    @ViewBuilder
    func PostersSectionView() -> some View {
        if !season.posters.isEmpty {
            MediaShelf("Posters") {
                ForEach(season.posters) { poster in
                    ArtworkImage(url: poster.filePath, aspectRatio: CGFloat(poster.aspectRatio))
                        .frame(width: Portrait.width(.small))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}

extension TVSeasonDetailView {

    func fetchData() {
        fetchDataTask = Task {
            try await season.fetchRelatedData()
        }
    }

    func setupPlayer(selected: TVEpisodeDetail?) {
        let episodes = availableEpisodes
        guard let index = episodes.firstIndex(where: { $0.id == selected?.id }) else {
            return
        }
        setupPlayerTask = Task {
            var items: [PlaylistItem] = []
            for episode in episodes {
                items.append(await episode.playlistItem())
            }
            player.setPlaylist(items)
            playerStartIndex = index
            playerPresented = true
        }
    }
}
