//
//  MusicView.swift
//  Arthub
//
//  Created by 张鸿燊 on 31/1/2024.
//

import SwiftUI
import MediaPlayer

struct MusicView: View {

    var viewModel: MusicViewModel
    @Environment(ArthubAudioPlayer.self) private var player

    init(viewModel: MusicViewModel? = nil) {
        self.viewModel = viewModel ?? MusicViewModel()
    }

    private var frameMinSize: CGSize = .init(width: 600, height: 400)

    var body: some View {
        @Bindable var viewModel = viewModel
        return MainView()
            .frame(minWidth: frameMinSize.width,
                   minHeight: frameMinSize.height)
            .focusEffect()
            .toolbar { ToolbarItems() }
            .searchable(text: $viewModel.searchText, placement: .automatic)
            .task{ viewModel.fetchData() }
            .refreshable{ viewModel.fetchData() }
            .navigationDestination(isPresented: $viewModel.playerPresented) {
                MusicPlayer(currentSong: viewModel.currentSong)
            }
            .onChange(of: player.currentItemID, initial: true, viewModel.handlePlayItemIDChange)
            .onDisappear(perform: player.optOut)
    }
    
}

// MARK: Toolbar

extension MusicView {
    
    @ToolbarContentBuilder
    func ToolbarItems() -> some ToolbarContent {
        @Bindable var viewModel = viewModel
        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: viewModel.fetchData) {
                if viewModel.isFetchingData {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            .disabled(viewModel.isFetchingData)

            Menu("Action", systemImage: "ellipsis.circle") {
                Menu("Sort By") {
                    Group {
                        Picker("", selection: $viewModel.selectedOrderProperty) {
                            ForEach(MusicOrderProperty.allCases) { order in
                                Text(order.localizedKey).tag(order)
                            }
                        }
                        
                        Picker("", selection: $viewModel.selectedOrder) {
                            Text("Ascending").tag(SortOrder.forward)
                            Text("Descending").tag(SortOrder.reverse)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            #if os(macOS)
            Button("Inspector", systemImage: "sidebar.right") {
                viewModel.toggleInspector(.info)
            }
            #endif
        }
    }
}

extension MusicView {

    @ViewBuilder
    func MainView() -> some View {
        MusicTable()
            .overlay {
                if viewModel.filteredSongs.isEmpty {
                    ContentUnavailableView.search
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { MiniPlayer() }
    }

    func editMetadata(_ song: Song) {
        viewModel.selectedSongID = song.id
        viewModel.inspectorContent = .info
        viewModel.inspectorPresented = true
    }

    @ViewBuilder
    func MiniPlayer() -> some View {
        MiniMusicPlayer(song: viewModel.currentSong,
                        lyricsPresented: viewModel.lyricsPresented,
                        onToggleLyrics: toggleLyrics,
                        onOpenPlayer: { viewModel.playerPresented = true },
                        onStartPlayback: startPlayback)
    }

    func toggleLyrics() {
        #if os(macOS)
        viewModel.toggleInspector(.lyrics)
        #else
        viewModel.playerPresented = true
        #endif
    }
    
    @ViewBuilder
    func MusicTable() -> some View {
        @Bindable var viewModel = viewModel
        Table(of: Song.self, selection: $viewModel.selectedSongID) {
            TableColumn("Title") { song in
                HStack(alignment: .center) {
                    MusicCover(song)
                    
                    VStack(alignment: .leading) {
                        Text(song.title).font(.headline)
                        if !song.isAvailable { Text("Unavailable").font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
            TableColumn("Duration") { Text($0.duration.formatted()) }
        } rows: {
            ForEach(viewModel.filteredSongs) { song in
                TableRow(song)
                    .contextMenu {
                        Button("Play", systemImage: "play.fill"){
                            Task { try await startPlay(from: song.id) }
                        }
                        Button("Edit Metadata", systemImage: "info.circle") {
                            editMetadata(song)
                        }
                        
                        NavigationLink {
                            AlbumDetailView(album: song.album, onEditMetadata: editMetadata)
                                .safeAreaInset(edge: .bottom, spacing: 0) { MiniPlayer() }
                        } label: {
                            Label("Album", systemImage: "music.note.list")
                        }

                        ShareLink(item: song.fileURL,
                                  message: Text(verbatim: song.title)) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
            }
        }
        .tableStyle(.inset)
        .tableColumnHeaders(.hidden)
        .scrollIndicators(.never, axes: .horizontal)
        .contextMenu(forSelectionType: Song.ID.self,
                     menu: { _ in },
                     primaryAction: { items in
            guard let item = items.first else { return }
            Task { try await startPlay(from: item)}
        })
    }
    
    
    @ViewBuilder
    func MusicCover(_ music: Song) -> some View {
        ArtworkImage(data: music.album.cover, aspectRatio: 1) {
            ImageButton(systemImage: "music.note")
        }
        .frame(width: 50, height: 50)
        .cornerRadius()
        .overlay { MusicCoverOverlay(music) }
    }
    
    @ViewBuilder
    func MusicCoverOverlay(_ music: Song) -> some View {
        let isPlaying = music.id == viewModel.currentSong?.id && player.isPlaying
        if isPlaying {
            ImageButton {
                
            } label: {
                Waveform(animated: isPlaying)
                    .foregroundStyle(.white)
            }
        }
    }

}


// MARK: Mini Player Component

extension MusicView {

    /// Play pressed with an empty queue: start from the selection, or a random song.
    func startPlayback() {
        Task {
            let songID = viewModel.selectedSongID ?? viewModel.songs.filter(\.isAvailable).randomElement()?.id
            guard let songID else { return }
            try await startPlay(from: songID)
        }
    }
}


// MARK: Inspector

/// Window-level inspector content for the Music tab, hosted by ContentView
/// so it spans the full window height beside the split view.
struct MusicInspector: View {

    var viewModel: MusicViewModel

    var body: some View {
        if viewModel.inspectorContent == .lyrics {
            LyricsInspectorView(song: viewModel.currentSong)
        } else if let song = viewModel.songs.first(where: { $0.id == viewModel.selectedSongID }) {
            MusicInspectorView(song: song)
        } else {
            ContentUnavailableView("No Selection",
                                   systemImage: "music.note",
                                   description: Text("Please select one item."))
        }
    }
}

#Preview {
    MusicView()
        .environment(ArthubAudioPlayer())
        .environment(WindowState())
}

extension MusicView {
    
    func startPlay(from: Song.ID) async throws {
        guard viewModel.songs.contains(where: { $0.id == from && $0.isAvailable }) else { return }
        viewModel.selectedSongID = from
        await setupPlayer()
        try player.start()
    }
    
    func setupPlayer() {
        let songs = viewModel.filteredSongs.filter(\.isAvailable)
        guard let index = songs.firstIndex(where: { $0.id == viewModel.selectedSongID }) else {
            return
        }
        var playableAssets: [NowPlayableStaticMetadata] = []
        for song in Array(songs[index...] + songs[..<index]) {
            var artwork: MPMediaItemArtwork? = nil
            if let cover = song.album.cover {
                artwork = MPMediaItemArtwork(data: cover)
            }
            let metadata = NowPlayableStaticMetadata(
                id: NSNumber(value: song.id.hashValue),
                assetURL: song.fileURL, mediaType: .audio, isLiveStream: false,
                title: song.title, artist: song.artist.name,
                artwork: artwork, albumArtist: song.album.artist.name,
                albumTitle: song.album.title)
            playableAssets.append(metadata)
        }
        player.preloadItems(playableAssets: playableAssets)
    }
}

#Preview {
    
    NavigationStack {
        MusicView()
            .environment(ArthubAudioPlayer())
    }
    
}
