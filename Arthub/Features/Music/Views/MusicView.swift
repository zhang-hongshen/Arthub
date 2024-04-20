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
                MusicPlayer(currentMusic: viewModel.currentMusic)
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
                ImageLoader(data: viewModel.currentMusic?.album.cover, aspectRatio: 1, contentMode: .fit) {
                    ImageButton(systemImage: "music.note")
                }
                .frame(height: height)
                .onTapGesture { viewModel.playerPresented = true }
                    
                VStack(alignment: .center) {
                    MarqueeText(verbatim: "\(viewModel.currentMusic?.title ?? "")  - \(viewModel.currentMusic?.album.title ?? "")").font(.headline)
                    MarqueeText(verbatim: "\(viewModel.currentMusic?.artist.name ?? "-")")
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
        let toolbarPlacement: ToolbarItemPlacement = .music
        #else
        let toolbarPlacement: ToolbarItemPlacement = .automatic
        #endif
                                                                   
        ToolbarItemGroup(placement: toolbarPlacement) {
            
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
                if viewModel.filteredMusics.isEmpty {
                    ContentUnavailableView.search
                }
            }
    }
    
    @ViewBuilder
    func MusicTable() -> some View {
        Table(of: MusicDetail.self, selection: $viewModel.selectedMusicID) {
            TableColumn("Title") { music in
                HStack(alignment: .center) {
                    MusicCover(music)
                    
                    VStack(alignment: .leading) {
                        Text(music.title).font(.headline)
                        Text(music.album.title).font(.subheadline)
                    }
                }
            }
            TableColumn("Artist") { Text($0.artist.name) }
            TableColumn("Duration") { Text($0.duration.formatted()) }
        } rows: {
            ForEach(viewModel.filteredMusics) { music in
                TableRow(music)
                    #if os(macOS)
                    .onHover { viewModel.hoveringMusicID = $0 ? music.id : nil }
                    #endif
                    .contextMenu {
                        Button("Play", systemImage: "play.fill"){
                            Task { try await startPlay(from: music.id) }
                        }
                        Button("Edit Metadata", systemImage: "info.circle") {
                            viewModel.selectedMusicID = music.id
                            viewModel.inspectorPresented = true
                        }
                        
                        NavigationLink {
                            AlbumDetailView(album: music.album)
                        } label: {
                            Label("Album", systemImage: "music.note.list")
                        }

                        ShareLink(item: music.fileURL,
                                  message: Text(verbatim: music.title)) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
            }
        }
        .tableStyle(.inset)
        .tableColumnHeaders(.hidden)
        .scrollIndicators(.never, axes: .horizontal)
        .contextMenu(forSelectionType: MusicDetail.ID.self,
                     menu: { _ in },
                     primaryAction: { items in
            guard let item = items.first else { return }
            Task { try await startPlay(from: item)}
        })
    }
    
    
    @ViewBuilder
    func MusicCover(_ music: MusicDetail) -> some View {
        ImageLoader(data: music.album.cover, aspectRatio: 1) {
            ImageButton(systemImage: "music.note")
        }
        .frame(width: 50, height: 50)
        .cornerRadius()
        .overlay { MusicCoverOverlay(music) }
    }
    
    @ViewBuilder
    func MusicCoverOverlay(_ music: MusicDetail) -> some View {
        let isPlaying = music.id == viewModel.currentMusic?.id && player.isPlaying
        let isHovering = music.id == viewModel.hoveringMusicID
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
                    let musicID =  viewModel.selectedMusicID ?? viewModel.musics.randomElement()?.id
                    guard let musicID else { return }
                    try await startPlay(from: musicID)
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
        if let music = viewModel.musics.first(where: { $0.id == viewModel.selectedMusicID }) {
            MusicInspectorView(music: music)
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
    
    func startPlay(from: MusicDetail.ID) async throws {
        viewModel.selectedMusicID = from
        await setupPlayer()
        try player.start()
    }
    
    func setupPlayer() {
        guard let index = viewModel.filteredMusics.firstIndex(where: { $0.id == viewModel.selectedMusicID }) else {
            return
        }
        var playableAssets: [NowPlayableStaticMetadata] = []
        for music in Array(viewModel.filteredMusics[index...] + viewModel.filteredMusics[0...index]) {
            var artwork: MPMediaItemArtwork? = nil
            if let cover = music.album.cover {
                artwork = MPMediaItemArtwork(data: cover)
            }
            let metadata = NowPlayableStaticMetadata(
                id: NSNumber(value: music.id.hashValue),
                assetURL: music.fileURL, mediaType: .audio, isLiveStream: false,
                title: music.title, artist: music.artist.name,
                artwork: artwork, albumArtist: music.album.artist.name,
                albumTitle: music.album.title)
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
