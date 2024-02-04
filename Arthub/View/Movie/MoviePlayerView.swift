//
//  MoviePlayerView.swift
//  shelf
//
//  Created by 张鸿燊 on 1/2/2024.
//

import SwiftUI
import AVKit

struct MoviePlayerView: View {
    
    @Binding var presented: Bool
    @Binding var movie: Movie
    
    @EnvironmentObject private var arthubPlayer: ArthubPlayer
    @State private var helpPresented: Bool = false
    @State private var controlPresented: Bool = false
    
    // playback control
    @State private var currentVolume: Float = 0.5
    
    @State private var paused: Bool = false
    @State private var fullScreen: Bool = false
    @State private var settingsPresented: Bool = false
    // detect user's seek
    @State private var sliderEditing: Bool = false
    
    var body: some View {
        ZStack {
            if let player = arthubPlayer.videoPlayer {
                PlayerView(player: player)
                    .overlay {
                        PlayOverlayView(player: player)
                    }
            }
        }
        .task {
            do {
                try await arthubPlayer.setVideoPlayer(url: Bundle.main.url(forResource: movie.filepath, withExtension:"mp4")!)
            } catch {
                print("Movie setPlayer error, \(error)")
            }
            
        }
        .onChange(of: fullScreen, initial: false) { oldValue, newValue in
            DispatchQueue.main.async {
                if !oldValue && newValue {
                    NSApplication.shared.mainWindow?.toggleFullScreen(nil)
                } else if oldValue && !newValue {
                    NSApplication.shared.mainWindow?.toggleFullScreen(NSWindow.StyleMask.fullScreen)
                }
            }
        }
        .onHover { hovering in
            controlPresented = hovering
        }
    }
}

extension MoviePlayerView {
    @ViewBuilder
    func PlayerView(player: AVPlayer) -> some View {
        VideoPlayer(player: player)
            .onAppear {
                player.seek(to: .init(seconds: movie.currentDuration, preferredTimescale: 1))
            }
            .onChange(of: arthubPlayer.currentDuration, initial: true) { _, newValue in
                if !sliderEditing {
                    movie.currentDuration  = newValue
                    if arthubPlayer.totalDurationValid() {
                        movie.progress = newValue / arthubPlayer.totalDuration
                        if movie.progress > 1 {
                            movie.progress = 1
                        }
                    }
                }
            }
            .onChange(of: presented) {
                arthubPlayer.reset()
            }
            .onChange(of: player.volume) {
                currentVolume = player.volume
            }
            .onChange(of: paused, initial: true) {
                paused ? player.pause() : player.play()
            }
            .onKeyPress(.init("?")) {
                helpPresented.toggle()
                return .handled
            }
    }
    
    @ViewBuilder
    func PlayOverlayView(player: AVPlayer) -> some View {
        VStack {
            HStack {
                HelpView()
                    .padding(5)
                    .background {
                        RoundedRectangle(cornerRadius: .defaultCornerRadius)
                            .fill(Color.highlightColor.opacity(0.8))
                    }
                    .opacity(controlPresented ? 1 : 0)
                    .keyboardShortcut(.init("?"))
                    .keyboardShortcut(.init("/"))
                Spacer()
            }
            .safeAreaPadding(5)
            Spacer()
            PlayBackControlView(player: player)
                .padding(5)
                .opacity(controlPresented ? 1 : 0)
                .frame(width: 350)
                .fixedSize()
        }
        PlayerSettingsView(player: player)
            
            .opacity(settingsPresented ? 1 : 0)
    }
    
    @ViewBuilder
    func PlayBackControlView(player: AVPlayer) -> some View {
        PlayBackControl(player: player)
            .overlay{
                Color.clear
                    .onKeyPress(.escape) {
                        presented = false
                        return .handled
                    }
            }
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: .defaultCornerRadius)
                    .fill(Color.highlightColor.opacity(0.4))
            }
    }
    
    @ViewBuilder
    func PlayBackControl(player: AVPlayer) -> some View {
        VStack {
            HStack {
                VolumeControlView(volume: $currentVolume)
                .onChange(of: currentVolume, initial: true) { _, newValue in
                    player.volume = newValue
                }
                
                Button {
                    player.seek(to: .init(seconds: arthubPlayer.currentDuration - 15, preferredTimescale: 1))
                } label: {
                    Image(systemName: "gobackward.15")
                }
                .keyboardShortcut(.leftArrow, modifiers: [])
                
                Button {
                    paused.toggle()
                } label: {
                    Image(systemName: paused ? "play.fill" : "pause.fill")
                }
                .keyboardShortcut(.space, modifiers: [])
                
                Button {
                    player.seek(to: .init(seconds: arthubPlayer.currentDuration + 15, preferredTimescale: 1))
                } label: {
                    Image(systemName: "goforward.15")
                }
                .keyboardShortcut(.rightArrow, modifiers: [])
                
                Button {
                    fullScreen.toggle()
                } label: {
                    Image(systemName: fullScreen ? "arrow.down.right.and.arrow.up.left" :
                            "arrow.up.left.and.arrow.down.right")
                }
                
                Button {
                    withAnimation {
                        settingsPresented.toggle()
                    }
                    controlPresented = settingsPresented ? false : controlPresented
                } label: {
                    Image(systemName: "ellipsis")
                        .rotationEffect(.degrees(90))
                }
                
            }
            .font(.title2)
            
            HStack(spacing: 5) {
                Text(movie.currentDuration.formatted([.hour, .minute, .second]))
                Slider(value: $movie.currentDuration, in: 0...arthubPlayer.totalDuration) {
                    newValue in
                        sliderEditing = newValue
                        if sliderEditing {
                            // pause for seeking smothly
                            paused = true
                        } else {
                            // resume to the original state
                            paused = false
                        }
                }
                .onChange(of: movie.currentDuration) { _, newValue in
                    if sliderEditing {
                        DispatchQueue.main.async {
                            arthubPlayer.videoPlayer?.seek(to: .init(seconds: newValue, preferredTimescale: 1))
                        }
                    }
                }
                Text(arthubPlayer.totalDuration.formatted([.hour, .minute, .second]))
                
            }
        }
        .buttonStyle(.borderless)
        
    }
}

extension MoviePlayerView {
    @ViewBuilder
    func HelpView() -> some View {
            
        Grid(alignment: .leadingFirstTextBaseline) {
            Text("help")
                .font(.title2)
            Group {
                GridRow {
                    Image(systemName: "space").gridColumnAlignment(.trailing)
                    Text("keyboardShortCut.playOrPause")
                }
                GridRow {
                    Image(systemName: "arrowshape.left.arrowshape.right").gridColumnAlignment(.trailing)
                    Text("keyboardShortCut.forwardOrBackward15seconds")
                }
                GridRow {
                    HStack {
                        Image(systemName: "arrowshape.up").gridColumnAlignment(.trailing)
                        Image(systemName: "arrowshape.down").gridColumnAlignment(.trailing)
                    }.gridColumnAlignment(.trailing)
                    Text("keyboardShortCut.increaseOrDecreaseVolume")
                }
            }
            .font(.title3)
            
        }
    }
    
    
    @ViewBuilder
    func PlayerSettingsView(player: AVPlayer) -> some View {
        HStack {
            Spacer()
                .onTapGesture {
                    settingsPresented = false
                }
            Rectangle()
                .fill()
                .overlay {
                    PlayerSettings()
                }
                .frame(width: 300)
        }
    }
    
    @ViewBuilder
    func PlayerSettings() -> some View {
        VStack {
            Text("To be continue")
        }
    }
}
