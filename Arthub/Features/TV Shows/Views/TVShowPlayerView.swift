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
    /// Episode the player should start from when it first appears.
    var startAtIndex: Int = 0
    /// Where playback should resume within the starting episode.
    var startAtTime: TimeInterval = 0

    @State private var episodesViewPresented: Bool = false
    @State private var currentTVEpisodeIndex: Int? = nil
    @State private var didStartPlayback: Bool = false

    var body: some View {
        VideoPlayerView(currentTime: Binding(
            get: { currentTVEpisode?.metrics.currentTime ?? 0 },
            set: { currentTVEpisode?.metrics.currentTime = $0 })) {
            episodesViewPresented = false
        } sidebarContent: {
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
        .task {
            guard !didStartPlayback else { return }
            didStartPlayback = true
            selectEpisode(at: startAtIndex, at: startAtTime)
        }
        .onChange(of: player.currentIndex, initial: true, handleCurrentIndexChange)
        .onChange(of: currentTVEpisodeIndex, handleSelectedIndexChange)
    }
}

extension TVShowPlayerView {

    private var currentTVEpisode: TVEpisodeDetail? {
        guard let currentTVEpisodeIndex, playlist.indices.contains(currentTVEpisodeIndex) else {
            return nil
        }
        return playlist[currentTVEpisodeIndex]
    }

    @ViewBuilder
    func EpisodesView() -> some View {
        ScrollView {
            ForEach(Array(playlist.enumerated()), id: \.offset) { index, episode in
                HStack(alignment: .center) {
                    ArtworkImage(url: episode.metadata.stillPath, aspectRatio: Landscape.aspectRatio)
                        .frame(width: Portrait.width(.small))
                        .cornerRadius()
                    VStack(alignment: .leading) {
                        Text(episode.metadata.name).font(.headline)
                        Text("Episode \(episode.metadata.episodeNumber)").font(.subheadline)
                    }
                    Spacer()
                    if index == currentTVEpisodeIndex {
                        Image(systemName: player.isPlaying
                              ? "waveform" : "pause")
                            .foregroundStyle(.tint)
                    }
                }
                .tag(index)
                .contentShape(.rect)
                .onTapGesture {
                    selectEpisode(at: index)
                }
            }
        }
    }

}

// MARK: Playback

extension TVShowPlayerView {

    /// Start playback at the given episode, resuming where the user left off.
    /// Tapping the already-playing episode is a no-op (does not rewind).
    func selectEpisode(at index: Int, at time: TimeInterval? = nil) {
        guard playlist.indices.contains(index) else { return }
        if player.currentIndex == index { return }
        currentTVEpisodeIndex = index
        let resumeAt = time ?? playlist[index].metrics.currentTime
        Task {
            try await player.start(from: index, at: resumeAt)
        }
    }

    /// The player moved on to another item (next/previous track,
    /// end-of-episode auto-advance) — keep our state in sync.
    func handleCurrentIndexChange(oldValue: Int?, newValue: Int?) {
        guard let newValue, playlist.indices.contains(newValue) else { return }
        currentTVEpisodeIndex = newValue
    }

    /// The user tapped a different episode in the sidebar.
    func handleSelectedIndexChange(oldValue: Int?, newValue: Int?) {
        guard let newValue, newValue != oldValue else { return }
        selectEpisode(at: newValue)
    }
}
