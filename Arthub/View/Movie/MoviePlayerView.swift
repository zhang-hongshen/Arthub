//
//  MoviePlayerView.swift
//  Arthub
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
    @State private var helpSize: CGSize = .init(width: 350, height: .zero)
    // playback control
    @State private var playbackControlSize: CGSize = .init(width: 350, height: .zero)
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
                    .frame(minWidth: max(playbackControlSize.width, helpSize.width),
                           minHeight: playbackControlSize.height + helpSize.height)
            }
        }
        .task {
            do {
                debugPrint("Begin setVideoPlayer")
                try await arthubPlayer.setVideoPlayer(url: Bundle.main.url(forResource: movie.filepath, withExtension:"mp4")!,
                                                      startTime: movie.currentTime)
            } catch {
                print("setVideoPlayer error, \(error)")
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
            .onChange(of: arthubPlayer.currentTime, initial: true) { _, newValue in
                if !sliderEditing {
                    movie.currentTime  = newValue
                    if arthubPlayer.durationValid() {
                        movie.progress = newValue / arthubPlayer.duration
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
                Spacer()
                HelpView()
                    .padding(5)
                    .background {
                        RoundedRectangle(cornerRadius: .defaultCornerRadius)
                            .fill(Color.highlightColor.opacity(0.8))
                    }
                    .opacity(controlPresented ? 1 : 0)
                    .keyboardShortcut(.init("?"))
                    .keyboardShortcut(.init("/"))
                    .overlay {
                        GeometryReader {proxy in
                            Color.clear.onAppear {
                                helpSize = proxy.size
                            }
                        }
                    }
            }
            .safeAreaPadding(5)
            Spacer()
            PlayBackControlView(player: player)
                .padding(5)
                .opacity(controlPresented ? 1 : 0)
                .frame(width: playbackControlSize.width)
                .fixedSize()
                .overlay {
                    GeometryReader {proxy in
                        Color.clear.onAppear {
                            playbackControlSize = proxy.size
                        }
                    }
                }
        }
        .inspector(isPresented: $settingsPresented) {
            PlayerSettingsView(player: player)
        }
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
                VolumeBar(volume: $currentVolume)
                .onChange(of: currentVolume, initial: true) { _, newValue in
                    player.volume = newValue
                }
                
                Button {
                    player.seek(to: .init(seconds: arthubPlayer.currentTime - 15, preferredTimescale: 1))
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
                    player.seek(to: .init(seconds: arthubPlayer.currentTime + 15, preferredTimescale: 1))
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
            
            ProgressBar(value: $movie.currentTime, total: $arthubPlayer.duration, format: [.hour, .minute, .second]) { newValue in
                sliderEditing = newValue
                if sliderEditing {
                    // pause for seeking smothly
                    paused = true
                } else {
                    // resume to the original state
                    paused = false
                }
            }
            .onChange(of: movie.currentTime) { _, newValue in
                if sliderEditing {
                    DispatchQueue.main.async {
                        arthubPlayer.videoPlayer?.seek(to: .init(seconds: newValue, preferredTimescale: 1))
                    }
                }
            }
        }
        .buttonStyle(.borderless)
        
    }
}

extension MoviePlayerView {
    @ViewBuilder
    func HelpView() -> some View {
        VStack(alignment: .center) {
            Text("common.help")
                .font(.title)
                .fontWeight(.bold)
            Grid(alignment: .leadingFirstTextBaseline) {
                
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
    }
    
    
    @ViewBuilder
    func PlayerSettingsView(player: AVPlayer) -> some View {
        VStack {
            Text("To be continue")
        }
    }
}

#Preview {
    MoviePlayerView(presented: .constant(true), movie: .constant(Movie.examples()[0]))
        .frame(width: 600, height: 500)
        .environmentObject(ArthubPlayer())
}
