//
//  MusicPlayerView.swift
//  Shelf
//
//  Created by 张鸿燊 on 1/2/2024.
//

import SwiftUI
import AVKit



struct MusicPlayerView: View {
    
    @Binding var presented: Bool
    @Bindable var music: Music
    
    
    @State private var playbackControlSize: CGSize = .init(width: 400, height: .bitWidth)
    @State private var lyricsSize: CGSize = .zero
    
    @State private var currentAngle: Double = 0.0
    @State private var desiredAngle: Double = 360.0
    
    @EnvironmentObject var arthubPlayer: ArthubPlayer
    
    // playback control
    @State private var shuffled: Bool = false
    @State private var paused: Bool = false
    @State private var currentDuration: TimeInterval = 0
    @State private var lyricsPresented: Bool = false
    @State private var currentVolume: Float = 0.5
    // detect user's seek
    @State private var seeking: Bool = false
    @State private var volumeEditing: Bool = false
    
    var body: some View {
        Color.clear.overlay {
            if let player = arthubPlayer.audioPlayer {
                PlayerOverlayView(player: player)
                    .opacity(presented ? 1 : 0)
                    .onAppear {
                        let duration: Double  = 30
                        let interval = 0.05
                        // angle per second
                        let step: Double = desiredAngle * interval / duration
                        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
                            if !paused {
                                DispatchQueue.main.async {
                                    currentAngle = (currentAngle + step).truncatingRemainder(dividingBy: desiredAngle)
                                }
                            }
                        }
                    }
                    .onChange(of: player.currentTime, initial: true) { _, newValue in
                        if !seeking {
                            self.currentDuration = newValue
                        }
                    }
                    .onChange(of: paused, initial: true) { _, newValue in
                        // handle player
                        if let player = arthubPlayer.audioPlayer {
                            if newValue {
                                player.pause()
                            }  else {
                                player.play()
                            }
                        }
                    }
            }
        }
        .frame(minWidth: playbackControlSize.width + lyricsSize.width, minHeight: playbackControlSize.height)
        .task {
            do {
                try await arthubPlayer.setAudioPlayer(url: Bundle.main.url(forResource: music.filepath, withExtension:"mp3")!)
            } catch {
                print("Music setPlayer error, \(error)")
            }
            
        }
            
    }
}

extension MusicPlayerView {
    
    @ViewBuilder
    func PlayerOverlayView(player: AVAudioPlayer) -> some View {
        HStack {
            VStack(spacing: 20) {
                let thumbnailWidth = playbackControlSize.width * 0.8
                Image(music.thumbnail)
                    .resizable()
                    .frame(width: thumbnailWidth, height: thumbnailWidth)
                    .scaledToFit()
                    .rounded(cornerRadius: thumbnailWidth / 2)
                    .aspectRatio(contentMode: .fill)
                    .rotationEffect(.degrees(currentAngle))

                
                Text(music.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                PlayBackControlView(player: player)
                    .fontWeight(.bold)
            }
            .frame(minWidth: playbackControlSize.width)
            .fixedSize()
            .padding(20)
            .overlay {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            playbackControlSize = proxy.size
                        }
                }
            }
            if lyricsPresented {
                TimeSyncedLyricsView(lyrics: music.lyrics, currentDuration: $currentDuration)
                    .overlay {
                        GeometryReader { proxy in
                            Color.clear
                                .onChange(of: lyricsPresented, initial: true) { oldValue, newValue in
                                    lyricsSize = newValue ? proxy.size : .zero
                                    debugPrint("lyricsWidth: \(lyricsSize.width)")
                                }
                    }

                }
            }
        }
        .animation(.easeInOut, value: lyricsPresented)
    }
    
    @ViewBuilder
    func PlayBackControlView(player: AVAudioPlayer) -> some View {
        VStack(spacing: 20) {
            Slider(value: $currentDuration, in: 0...arthubPlayer.totalDuration) {
            } minimumValueLabel: {
                Text(currentDuration.formatted([.minute, .second]))
            } maximumValueLabel: {
                Text(arthubPlayer.totalDuration.formatted([.minute, .second]))
            } onEditingChanged: { newValue in
                if seeking && !newValue {
                    player.seek(time: currentDuration)
                    player.play()
                }
                seeking = newValue
            }
            
            
            HStack {
                Button {
                    shuffled.toggle()
                } label: {
                    Image(systemName: shuffled ? "square.fill" : "shuffle")
                }
                
                Spacer()
                
                HStack(spacing: 30) {
                    Button {

                    } label: {
                        Image(systemName: "backward.fill")
                    }
                    .font(.title)
                    
                    Button {
                        paused.toggle()
                    } label: {
                        Image(systemName: paused ? "play.fill" : "pause.fill")
                    }
                    .font(.largeTitle)
                    .keyboardShortcut(.space, modifiers: [])
                    
                    Button {
                        
                    } label: {
                        Image(systemName: "forward.fill")
                    }
                    .font(.title)
                }
                
                
                Spacer()
                
                Button {
                    withAnimation {
                        lyricsPresented.toggle()
                    }
                } label: {
                    Image(systemName: "quote.bubble")
                }
            }
            .buttonStyle(.borderless)
            
            VolumeControlView(volume: $currentVolume)
                .onChange(of: currentVolume, initial: true) { _, newValue in
                    player.volume = newValue
                }
            
        }
    }
}

#Preview {
    MusicPlayerView(presented: .constant(true), 
                    music: Music.examples()[0])
        .frame(width: 700, height: 600)
}
