//
//  MusicPlayerView.swift
//  Arthub
//
//  Created by 张鸿燊 on 1/2/2024.
//

import SwiftUI
import AVFoundation
import Logging

struct MusicPlayerView: View {
    
    @State var music: [Music]
    @EnvironmentObject private var player: ArthubAudioPlayer
    @Environment(WindowState.self) private var windowState
    @Environment(\.presentationMode) private var presentationMode
    @State private var playbackControlSize: CGSize = .init(width: 400, height: .zero)
    @State private var lyricsSize: CGSize = .zero
    // playback control
    @State private var shuffled: Bool = false
    @State private var currentTime: TimeInterval = 0
    @State private var lyricsPresented: Bool = false
    @State private var currentVolume: Float = 0.5
    // detect user's seek
    @State private var seeking: Bool = false
    @State private var volumeEditing: Bool = false
    
    private var lyrics: [Lyric] {
        guard let index = player.currentIndex,
              let url = music[index].lyrics else {
            return []
        }
        return Lyric.loadLyrics(url: url)
    }
    
    var body: some View {
        
        AsyncImage(url: player.currentPlaylistItem?.cover,
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
        .frame(minWidth: playbackControlSize.width,
               minHeight: playbackControlSize.height)
        .blur(radius: 50)
        .overlay {
            PlayerOverlayView()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .windowToolbar)
        .onAppear{
            windowState.push(.detailOnly)
        }
        .task(priority: .userInitiated) {
            do {
                try await player.start(musicList: music)
            } catch {
                Logger.shared.error("start error, \(error)")
            }
        }
        .onChange(of: player.currentTime, initial: true) { _, newValue in
            if !seeking {
                currentTime = newValue
            }
        }
        .onChange(of: currentVolume, initial: true) { _, newValue in
            player.setVolume(newValue)
        }
    }
}

extension MusicPlayerView {
    
    @ViewBuilder
    func PlayerOverlayView() -> some View {
        HStack(alignment: .center) {
            
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
                
                
                AsyncImage(url: player.currentPlaylistItem?.cover,
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
                .frame(width: playbackControlSize.width,
                       height: playbackControlSize.width)
                .scaleEffect(player.isPlaying)
                .cornerRadius()
                .animation(.smooth, value: player.isPlaying)
                
                HStack {
                    VStack(alignment: .leading, spacing: 5){
                        Text(player.currentPlaylistItem?.title ?? "")
                            .font(.title)
                            .fontWeight(.bold)
                        Text(player.currentPlaylistItem?.artists ?? "")
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
                        }
                }
            }
            if lyricsPresented {
                @Bindable var player = player
                TimeSyncedLyricsView(lyrics: lyrics,
                                     currentTime: $player.currentTime) { lyric in
                    player.seek(to: lyric.startedAt)
                }
                .overlay {
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear {
                                lyricsSize = proxy.size
                            }
                    }
                }
            }
        }
        .animation(.easeInOut, value: lyricsPresented)
    }
    
    @ViewBuilder
    func PlaybackControlView() -> some View {
        
        VStack(spacing: 20) {

            ArthubSlider(value: $currentTime,
                         in: 0...(player.currentPlaylistItem?.duration ?? 0),
                        onEditingChanged: { newValue in
                if seeking && !newValue {
                    player.seek(to: currentTime)
                }
                seeking = newValue
            })
            
            HStack {
                Text(currentTime.formatted())
                Spacer()
                Text(player.currentPlaylistItem?.duration.formatted() ?? "-:-")
            }
            
            HStack {
                
                Button {
                    
                } label: {
                    Image(systemName: "shuffle")
                        .symbolVariant(.rectangle.fill)
                }
                
                Spacer()
                
                HStack(spacing: 30) {
                    Button {
                        
                    } label: {
                        Image(systemName: "backward.fill")
                    }
                    
                    Button {
                        if player.isPlaying {
                            player.pause()
                        } else {
                            do { try player.play() }
                            catch { Logger.shared.error("start error, \(error)") }
                        }
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.fill": "play.fill")
                    }
                    .keyboardShortcut(.space, modifiers: [])
                    
                    Button {
                        
                    } label: {
                        Image(systemName: "forward.fill")
                    }
                }
                
                Spacer()
                
                Button {
                    lyricsPresented.toggle()
                } label: {
                    Image(systemName: "quote.bubble")
                        .symbolVariant(lyricsPresented ? .square.fill : .none)
                }
            }
            .buttonStyle(.borderless)
            .font(.title2)
            
            VolumeBar(volume: $currentVolume)
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
