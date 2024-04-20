//
//  TVShowPlayerView.swift
//  Arthub
//
//  Created by 张鸿燊 on 3/3/2024.
//

import SwiftUI

struct TVShowPlayerView: View {

    @Environment(ArthubVideoPlayer.self) private var player
    
    var playlist: [TVEpisodeDetail]
    @State private var episodesViewPresented: Bool = false
    @State var currentTVEpisodeID: TVEpisodeDetail.ID? = nil
    
    private var currentIndex: Int? {
        playlist.firstIndex { $0.id == currentTVEpisodeID}
    }
    
    var body: some View {
        VideoPlayerView(currentTime: Binding(
            get: { if let index = currentIndex { playlist[index].metrics.currentTime } else { 0 }},
            set: { if let index = currentIndex { playlist[index].metrics.currentTime = $0 }} )) {
            episodesViewPresented = false
        } sidebarContent :{
            EpisodesView()
                .background(.ultraThinMaterial)
                .opacity(episodesViewPresented ? 1 : 0)
        } controlsTrailingContent: {
            Button {
                episodesViewPresented.toggle()
            } label: {
                Image(systemName: "square.stack")
            }
        }
        .onChange(of: player.currentItemID, initial: true, handlePlayItemIDChange)
            
    }
}

extension TVShowPlayerView {
    
    @ViewBuilder
    func EpisodesView() -> some View {
        ScrollView {
            ForEach(playlist.sorted(using: KeyPathComparator(\.metadata.episodeNumber,
                                                              order: .forward))) { episode in
                HStack(alignment: .center) {
                    ImageLoader(url: episode.metadata.stillPath, aspectRatio: Landscape.aspectRatio)
                        .frame(width: Portrait.width(.small))
                        .cornerRadius()
                    VStack(alignment: .leading) {
                        Text(episode.metadata.name).font(.headline)
                        Text("Episode \(episode.metadata.episodeNumber)").font(.subheadline)
                    }
                }
                .tag(episode.id)
                .onTapGesture {
                    currentTVEpisodeID = episode.id
                }
            }
        }
    }

}

// MARK: Operation

extension TVShowPlayerView {
    
    func handlePlayItemIDChange(oldValue: Int? , newValue: Int?) {
        guard let id = newValue else {
            self.currentTVEpisodeID = nil
            return
        }
        self.currentTVEpisodeID = playlist.first{ $0.id.hashValue == id }?.id
    }
    
    func handleCurrentTVEpisodeIDChange(oldValue: TVEpisodeDetail.ID? , newValue: TVEpisodeDetail.ID?) {
        guard let index = playlist.firstIndex(where: { $0.id == newValue }) else {
            return
        }
        Task(priority: .userInitiated) {
            try await player.start(from: index, at: playlist[index].metrics.currentTime)
        }
    }
}
