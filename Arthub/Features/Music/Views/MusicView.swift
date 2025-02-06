//
//  MusicView.swift
//  Arthub
//
//  Created by 张鸿燊 on 31/1/2024.
//

import SwiftUI
import MediaPlayer

struct MusicView: View {
    
    @State private var viewModel = MusicViewModel()
    @Environment(ArthubAudioPlayer.self) private var player
    
    private var frameMinSize: CGSize = .init(width: 600, height: 400)
    
    var body: some View {
        MainView()
            .frame(minWidth: frameMinSize.width,
                   minHeight: frameMinSize.height)
            .focusEffect()
            .toolbar {
                MiniMusicPlayer()
                ToolbarItems()
            }
            .searchable(text: $viewModel.searchText, placement: .automatic)
            #if os(macOS)
            .inspector(isPresented: $viewModel.inspectorPresented) {
                InspectorView()
                    .inspectorColumnWidth(min: 300, ideal: 300, max: 400)
            }
            #endif
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
    func MiniMusicPlayer() -> some ToolbarContent {
        #if os(macOS)
        let placement: ToolbarItemPlacement = .destructiveAction
        #else
        let placement: ToolbarItemPlacement = .bottomBar
        #endif
        
        let height: CGFloat = 44
        
        ToolbarItemGroup(placement: placement) {
            HStack {
                ImageLoader(data: viewModel.currentSong?.album.cover, aspectRatio: 1, contentMode: .fit) {
                    ImageButton(systemImage: "music.note")
                }
                .frame(height: height)
                .onTapGesture { viewModel.playerPresented = true }
                    
                VStack(alignment: .center) {
                    MarqueeText(verbatim: "\(viewModel.currentSong?.title ?? "")  - \(viewModel.currentSong?.album.title ?? "")").font(.headline)
                    MarqueeText(verbatim: "\(viewModel.currentSong?.artist.name ?? "-")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 100)
                
                Spacer()
        
                #if os(iOS)
                if !UIDevice.isIPhone {
                    MusicPlayer.ShuffleButton()
                }
                #else
                MusicPlayer.ShuffleButton()
                #endif

                MusicPlayer.PreviousTrackButton()
                TogglePlayPauseButton()
                MusicPlayer.NextTrackButton()

                #if os(iOS)
                if !UIDevice.isIPhone {
                    MusicPlayer.PlaybackModeButton()
                }
                #else
                MusicPlayer.PlaybackModeButton()
                #endif
            }
            .imageScale(.large)
            #if os(iOS)
            .frame(height: height)
            .padding(Default.cornerRadius)
            .background(.ultraThinMaterial, in: RoundedRectangle())
            .safeAreaPadding(.bottom)
            #endif
        }
    }
    
    @ToolbarContentBuilder
    func ToolbarItems() -> some ToolbarContent {
        #if os(macOS)
        let placement: ToolbarItemPlacement = .music
        #else
        let placement: ToolbarItemPlacement = .automatic
        #endif
                                                                   
        ToolbarItemGroup(placement: placement) {
            
            Spacer()
            
            if viewModel.isFetchingData {
                ProgressView().controlSize(.small)
            } else {
                Button("Refresh", systemImage: "arrow.clockwise", action: viewModel.fetchData)
            }
            
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
                viewModel.inspectorPresented.toggle()
            }
            #endif
        }
    }
}

extension MusicView {
    
    @ViewBuilder
    func MainView() -> some View {
        MusicTable()
            .ignoresSafeArea(edges: .bottom)
            .overlay {
                if viewModel.filteredSongs.isEmpty {
                    ContentUnavailableView.search
                }
            }
    }
    
    @ViewBuilder
    func MusicTable() -> some View {
        Table(of: Song.self, selection: $viewModel.selectedSongID) {
            TableColumn("Title") { song in
                HStack(alignment: .center) {
                    MusicCover(song)
                    
                    VStack(alignment: .leading) {
                        Text(song.title).font(.headline)
                        Text(song.album.title).font(.subheadline)
                    }
                }
            }
            TableColumn("Artist") { Text($0.artist.name) }
            TableColumn("Duration") { Text($0.duration.formatted()) }
        } rows: {
            ForEach(viewModel.filteredSongs) { song in
                TableRow(song)
                    #if os(macOS)
                    .onHover { viewModel.hoveringSongID = $0 ? song.id : nil }
                    #endif
                    .contextMenu {
                        Button("Play", systemImage: "play.fill"){
                            Task { try await startPlay(from: song.id) }
                        }
                        Button("Edit Metadata", systemImage: "info.circle") {
                            viewModel.selectedSongID = song.id
                            viewModel.inspectorPresented = true
                        }
                        
                        NavigationLink {
                            AlbumDetailView(album: song.album)
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
        ImageLoader(data: music.album.cover, aspectRatio: 1) {
            ImageButton(systemImage: "music.note")
        }
        .frame(width: 50, height: 50)
        .cornerRadius()
        .overlay { MusicCoverOverlay(music) }
    }
    
    @ViewBuilder
    func MusicCoverOverlay(_ music: Song) -> some View {
        let isPlaying = music.id == viewModel.currentSong?.id && player.isPlaying
        let isHovering = music.id == viewModel.hoveringSongID
        ZStack {
            if isPlaying && !isHovering {
                ImageButton {
                    
                } label: {
                    Waveform(animated: isPlaying)
                }
            }
            if isHovering {
                ImageButton(systemImage: isPlaying ? "pause.fill" : "play.fill")
                    .onTapGesture {
                        if isPlaying {
                            player.togglePlayPause()
                        } else {
                            Task { try await startPlay(from: music.id) }
                        }
                    }
            }
        }
    }

}


// MARK: Mini Player Component

extension MusicView {
    
    @ViewBuilder
    func TogglePlayPauseButton() -> some View {
        Button {
            if player.isPlaylistEmpty {
                Task {
                    let songID =  viewModel.selectedSongID ?? viewModel.songs.randomElement()?.id
                    guard let songID else { return }
                    try await startPlay(from: songID)
                }
            } else {
                player.togglePlayPause()
            }
        } label: {
            Image(systemName: player.isPlaying ? "pause.fill": "play.fill")
        }
    }
}


// MARK: Inspector

extension MusicView {
    
    @ViewBuilder
    func InspectorView() -> some View {
        if let song = viewModel.songs.first(where: { $0.id == viewModel.selectedSongID }) {
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
        viewModel.selectedSongID = from
        await setupPlayer()
        try player.start()
    }
    
    func setupPlayer() {
        guard let index = viewModel.filteredSongs.firstIndex(where: { $0.id == viewModel.selectedSongID }) else {
            return
        }
        var playableAssets: [NowPlayableStaticMetadata] = []
        for song in Array(viewModel.filteredSongs[index...] + viewModel.filteredSongs[0...index]) {
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
