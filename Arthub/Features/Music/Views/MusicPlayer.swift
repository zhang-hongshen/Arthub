//
//  MusicPlayer.swift
//  Arthub
//
//  Created by 张鸿燊 on 1/2/2024.
//

import SwiftUI
import AVFoundation
import MediaPlayer


fileprivate struct MusicPlayerSizePreferenceKey: PreferenceKey {
    
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = defaultValue
    }
}

struct MusicPlayer: View {
    
    var currentMusic: MusicDetail?
    // playback control
    @State private var currentTime: TimeInterval = 0
    @State private var lyricsPresented: Bool = false
    // detect user's seek
    @State private var seeking: Bool = false

    @Environment(ArthubAudioPlayer.self) private var player
    @Environment(WindowState.self) private var windowState
    
    private let frameMinSize = CGSize(width: 600, height: 450)
    
    var body: some View {
        
        Background()
            .ignoresSafeArea(edges: .top)
            .overlay {
                Overlay()
                    .animation(.snappy, value: lyricsPresented)
            }
            .frame(minWidth: frameMinSize.width,
                   minHeight: frameMinSize.height)
            .navigationTitle("")
            .toolbar{ ToolbarItems() }
            .toolbarBackground(.clear.opacity(0), for: .automatic)
            #if canImport(AppKit)
            .hideToolbarWhenFullscreen()
            #endif
            .onAppear(perform: windowState.enterFullScreen)
            .onChange(of: player.currentTime, initial: true) { _, newValue in
                if !seeking {
                    currentTime = newValue
                }
            }
            .onDisappear(perform: windowState.exitFullScreen)
        
    }
}


// MARK: Toolbar

extension MusicPlayer {
    
    @ToolbarContentBuilder
    func ToolbarItems() -> some ToolbarContent {
        
        #if os(macOS)
        let toolbarPlacement: ToolbarItemPlacement = .primaryAction
        #else
        let toolbarPlacement: ToolbarItemPlacement = .bottomBar
        #endif
        
        ToolbarItemGroup(placement: toolbarPlacement) {
            Button {
                lyricsPresented.toggle()
            } label: {
                Image(systemName: "quote.bubble")
                    .symbolVariant(lyricsPresented ? .fill : .none)
            }
            
            DevicePickerView(player: player.player)
        }
    }
}

// MARK: Background

extension MusicPlayer {
    
    @ViewBuilder
    func Background() -> some View {
        
        var backgroundColor: Color {
            if let currentMusic,
               let cover = currentMusic.album.cover,
               let cgImage = CIImage(data: cover),
               let averageColor = cgImage.averageColor {
                Color(cgColor: averageColor)
            } else {
                .secondary
            }
        }
        
        Rectangle().fill(backgroundColor.gradient)
    }
    
}

// MARK: Player Overlay

extension MusicPlayer {
    
    @ViewBuilder
    func Overlay() -> some View {
        GeometryReader { proxy in
            HStack(alignment: .center, spacing: 0) {
                PlayerView()
                    .frame(width: proxy.size.width / 2)
                
                if lyricsPresented {
                    TimeSyncedLyricsView(
                        lyrics: currentMusic?.lyrics.body ?? [],
                        syncedTime: Binding(
                            get: { currentTime },
                            set: { _ in })) { lyric in
                                player.seek(to: lyric.start)
                            }

                }
            }
            .frame(width: proxy.size.width,
                   height: proxy.size.height)
        }
    }
    
    @ViewBuilder
    func PlayerView() -> some View {
        
        VStack(alignment: .center) {
            MusicCover()
            
            MusicInfoView()
            
            PlaybackControlView()
        }
        .safeAreaPadding()
    }
    
    @ViewBuilder
    func MusicCover() -> some View {
        ImageLoader(data: currentMusic?.album.cover, aspectRatio: 1, contentMode: .fit) {
            ImageButton(systemImage: "music.note")
        }
        .shadow()
        .cornerRadius()
        .scaleEffect(player.isPlaying)
    }
    
    
    @ViewBuilder
    func MusicInfoView() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 5){
                Text(verbatim: currentMusic?.title ?? "-")
                    .font(.title.bold())

                Text(verbatim: currentMusic?.artist.name ?? "-")
                    .font(.headline)
            }
            Spacer()
        }
    }
    
    @ViewBuilder
    func PlaybackControlView() -> some View {
        
        Grid(verticalSpacing: 30) {
            GridRow {
                Text(currentTime.formatted())
                ArthubSlider(value: $currentTime,
                             in: 0...player.duration,
                             onEditingChanged: { newValue in
                    if seeking && !newValue {
                        player.seek(to: currentTime)
                    }
                    seeking = newValue
                }).gridCellColumns(3)
                Text(player.duration.rounded().formatted())
            }
            
            GridRow {
                ShuffleButton()
                PreviousTrackButton()
                TogglePlayPauseButton().font(.largeTitle)
                NextTrackButton()
                PlaybackModeButton()
            }
            .imageScale(.large)
            
            GridRow {
                VolumeBar(volume: Binding(
                    get: { player.volume },
                    set: { player.volume = $0 }
                )).font(.title2)
            }.gridCellColumns(5)
        }
    }
    
}

extension MusicPlayer {
    
    
    struct ShuffleButton : View {
        
        @Environment(ArthubAudioPlayer.self) private var player
        
        var body: some View {
            Button(action: player.toggleShuffle) {
                Image(systemName: "shuffle.circle")
                    .symbolVariant(player.shuffled ? .fill : .none)
            }.buttonStyle(.borderless)
            
        }
    }
    
    struct PreviousTrackButton: View {
        
        @Environment(ArthubAudioPlayer.self) private var player
        
        var body: some View {
            Button(action: player.previousTrack) {
                Image(systemName: "backward.fill")
            }.buttonStyle(.borderless)
            .disabled(player.isPlaylistEmpty)
            
        }
    }
    
    struct TogglePlayPauseButton: View {
        
        @Environment(ArthubAudioPlayer.self) private var player
        
        var body: some View {
            Button(action: player.togglePlayPause) {
                Image(systemName: player.isPlaying ? "pause": "play")
                    .symbolVariant(.fill)
            }.buttonStyle(.borderless)
            .keyboardShortcut(.space, modifiers: [])
        }
    }
    
    struct NextTrackButton: View {
        
        @Environment(ArthubAudioPlayer.self) private var player
        
        var body: some View {
            Button(action: player.nextTrack) {
                Image(systemName: "forward.fill")
            }.buttonStyle(.borderless)
            .disabled(player.isPlaylistEmpty)
        }
    }
    
    struct PlaybackModeButton: View {
        
        @Environment(ArthubAudioPlayer.self) private var player
        
        var body: some View {
            Button(action: player.nextPlayerMode) {
                Image(systemName: player.playerMode.systemImageName)
            }.buttonStyle(.borderless)
        }
    }
}

#Preview {
    MusicPlayer(currentMusic:
                        MusicDetail(fileURL: URL(string: "")!,
                                    duration: 50, artist: ArtistDetail(),
                                    lyrics: LyricsDetail(),
                                    album: AlbumDetail(artist: ArtistDetail())))
    .environment(ArthubAudioPlayer())
    .environment(WindowState())
}
