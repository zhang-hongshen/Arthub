//
//  MusicPlayerView.swift
//  Arthub
//
//  Created by 张鸿燊 on 1/2/2024.
//

import SwiftUI
import AVFoundation
import Logging
import MediaPlayer

struct MusicPlayerView: View {
    
    @State var musics: [Music]
    @EnvironmentObject private var player: ArthubAudioPlayer
    @Environment(WindowState.self) private var windowState
    @Environment(\.presentationMode) private var presentationMode
    @State private var playbackControlSize: CGSize = .init(width: 400, height: .zero)
    @State private var lyricsSize: CGSize = .init(width: 200, height: .zero)
    private var frameMinSize: CGSize {
        return .init(width: playbackControlSize.width + (lyricsPresented ? lyricsSize.width : 0),
                     height: playbackControlSize.height)
    }
    // playback control
    @State private var shuffled: Bool = false
    @State private var currentTime: TimeInterval = 0
    @State private var lyricsPresented: Bool = false
    // detect user's seek
    @State private var seeking: Bool = false
    
    @State private var currentLyrics: [Lyric] = []
    @State private var currentMusic: Music? = nil

    
    var body: some View {
        
        AsyncImage(url: currentMusic?.album?.cover,
                   transaction: .init(animation: .smooth)
        ) { phase in
            switch phase {
            case .empty:
                DefaultImageView()
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure(let error):
                ErrorImageView(error: error)
            @unknown default:
                fatalError()
            }
        }
        .frame(minWidth: frameMinSize.width,
               minHeight: frameMinSize.height)
        .blur(radius: 60)
        .overlay {
            PlayerOverlayView()
                .animation(.snappy, value: lyricsPresented)
        }
        .safeAreaPadding(15)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .windowToolbar)
        .onAppear{
            windowState.push(.detailOnly)
        }
        .onChange(of: player.currentTime, initial: true) { _, newValue in
            if !seeking {
                currentTime = newValue
            }
        }
        .onChange(of: player.currentIndex, initial: true) { oldValue, newValue in
            guard let index = newValue else {
                self.currentMusic = nil
                self.currentLyrics = []
                return
            }
            self.currentMusic = musics[index]
            guard let url = musics[index].lyrics else {
                self.currentLyrics = []
                return
            }
            self.currentLyrics =  Lyric.loadLyrics(url: url)
        }
        .task(priority: .userInitiated) {
            player.setupItems(musics: musics)
            do {
                try player.start()
            } catch {
                
            }
        }
    }
}

extension MusicPlayerView {
    
    @ViewBuilder
    func PlayerOverlayView() -> some View {
        HStack(alignment: .top, spacing: 20) {
            
            VStack(alignment: .center) {
                HStack {
                    Button {
                        exit()
                    } label: {
                        Image(systemName: "chevron.left").font(.title)
                    }
                    .buttonStyle(.borderless)
                    .cursor()
                    .keyboardShortcut(.escape, modifiers: [])
                    
                    
                    Spacer()
                }
                
                Spacer()
                
                AsyncImage(url: currentMusic?.album?.cover,
                           transaction: .init(animation: .smooth)
                ) { phase in
                    switch phase {
                    case .empty:
                        DefaultImageView()
                    case .success(let image):
                        image.resizable().scaledToFit()
                            
                    case .failure(let error):
                        ErrorImageView(error: error)
                    @unknown default:
                        fatalError()
                    }
                }
                .cornerRadius()
                .frame(width: playbackControlSize.width,
                       height: playbackControlSize.width)
                .scaleEffect(player.playerState == .playing)
                
  
                HStack {
                    VStack(alignment: .leading, spacing: 5){
                        Text(currentMusic?.title ?? "-")
                            .font(.title)
                            .fontWeight(.bold)
                        Text(currentMusic?.artists.formatted() ?? "-")
                    }
                    Spacer()
                }
                
                PlaybackControlView()
                    .fontWeight(.bold)
            }
            .frame(width: playbackControlSize.width)
            .fixedSize()
            .overlay {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            playbackControlSize = proxy.size
                            lyricsSize.height = proxy.size.height
                        }
                }
            }
            
            if lyricsPresented {
                TimeSyncedLyricsView(
                    lyrics: $currentLyrics,
                    syncedTime: Binding(
                        get: { player.currentTime},
                        set: { _ in })) { lyric in
                    player.seek(to: lyric.start)
                }
            }
        }
    }
    
    @ViewBuilder
    func PlaybackControlView() -> some View {
        
        VStack(spacing: 20) {

            ArthubSlider(value: $currentTime,
                         in: 0...player.duration,
                        onEditingChanged: { newValue in
                if seeking && !newValue {
                    player.seek(to: currentTime)
                }
                seeking = newValue
            })
            
            HStack {
                Text(currentTime.formatted())
                Spacer()
                Text(player.duration.formatted())
            }
            
            HStack {
                
                Button {
                    shuffled.toggle()
                } label: {
                    Image(systemName: "shuffle.circle")
                        .symbolVariant(shuffled ? .fill : .none)
                }
                
                Spacer()
                
                HStack(spacing: 30) {
                    Button {
                        
                    } label: {
                        Image(systemName: "backward")
                    }
                    
                    Button {
                        player.togglePlayPause()
                    } label: {
                        Image(systemName: player.playerState == .playing ? "pause": "play")
                    }
                    .keyboardShortcut(.space, modifiers: [])
                    
                    Button {
                        
                    } label: {
                        Image(systemName: "forward")
                    }
                }
                .symbolVariant(.fill)
                
                Spacer()
                
                Button {
                    lyricsPresented.toggle()
                } label: {
                    Image(systemName: "quote.bubble")
                        .symbolVariant(lyricsPresented ? .fill : .none)
                }
            }
            .buttonStyle(.borderless)
            .font(.title2)
            
            VolumeBar(volume: $player.volume)
                .font(.title2)
        }
    }
        
}

extension MusicPlayerView {
    
    func exit() {
        self.presentationMode.wrappedValue.dismiss()
        windowState.pop()
    }
}
