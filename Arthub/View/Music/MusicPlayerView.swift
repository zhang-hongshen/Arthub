//
//  MusicPlayerView.swift
//  Arthub
//
//  Created by 张鸿燊 on 1/2/2024.
//

import SwiftUI
import AVKit


struct MusicPlayerView: View {
    
    @Binding var presented: Bool
    @Bindable var music: Music
    
    
    @State private var playbackControlSize: CGSize = .init(width: 400, height: .zero)
    @State private var lyricsSize: CGSize = .zero
    
    @State private var currentAngle: Double = 0.0
    @State private var desiredAngle: Double = 360.0
    
    @EnvironmentObject var arthubPlayer: ArthubPlayer
    
    // playback control
    @State private var shuffled: Bool = false
    @State private var paused: Bool = false
    @State private var currentTime: TimeInterval = 0
    @State private var lyricsPresented: Bool = false
    @State private var currentVolume: Float = 0.5
    // detect user's seek
    @State private var seeking: Bool = false
    @State private var volumeEditing: Bool = false
    
    var body: some View {
        PlayerOverlayView()
        .background{
            Image(music.thumbnail)
                .blur(radius: 45)
        }
        .frame(minWidth: playbackControlSize.width + lyricsSize.width, minHeight: playbackControlSize.height)
        .opacity(presented ? 1 : 0)
        .task(priority: .high) {
            do {
                try await arthubPlayer.setAudioPlayer(url: Bundle.main.url(forResource: music.filepath, withExtension:"mp3")!)
            } catch {
                print("set AudioPlayer error, \(error)")
            }
        }
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
    }
}

extension MusicPlayerView {
    
    @ViewBuilder
    func PlayerOverlayView() -> some View {
        HStack {
            VStack(alignment: .center, spacing: 20) {
                let width = playbackControlSize.width * 0.8
                Image(music.thumbnail)
                    .resizable()
                    .frame(width: width, height: width)
                    .scaledToFit()
                    .rounded(cornerRadius: width / 2)
                    .blur(radius: 55)
                    .overlay {
                        let thumbnailWidth = playbackControlSize.width * 0.5
                        Image(music.thumbnail)
                            .resizable()
                            .frame(width: thumbnailWidth, height: thumbnailWidth)
                            .scaledToFit()
                            .rounded(cornerRadius: thumbnailWidth / 2)
                            .aspectRatio(contentMode: .fill)
                            .rotationEffect(.degrees(currentAngle))
                    }
                HStack {
                    VStack(alignment: .leading, spacing: 5){
                        Text(music.name)
                            .font(.title)
                            .fontWeight(.bold)
                        Text(music.name)
                            .fontWeight(.semibold)
                    }
                    Spacer()
                }
                
                
                PlayBackControlView()
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
                TimeSyncedLyricsView(lyrics: music.lyrics, currentTime: $currentTime) { lyric in
                    arthubPlayer.audioPlayer?.seek(to: lyric.startedAt)
                }
                .overlay {
                    GeometryReader { proxy in
                        Color.clear
                            .onChange(of: lyricsPresented, initial: true) { oldValue, newValue in
                                lyricsSize = newValue ? proxy.size : .zero
                            }
                    }
                }
            }
        }
        .animation(.easeInOut, value: lyricsPresented)
    }
    
    @ViewBuilder
    func PlayBackControlView() -> some View {
        if let player = arthubPlayer.audioPlayer {
            VStack(spacing: 20) {
                ProgressBar(value: $currentTime, total: $arthubPlayer.duration,
                            format: [.minute, .second]) { newValue in
                    if seeking && !newValue {
                        player.seek(to: currentTime)
                        player.play()
                    }
                    seeking = newValue
                }
                .onChange(of: player.currentTime, initial: true) { _, newValue in
                    if !seeking {
                        self.currentTime = newValue
                    }
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
                    .onChange(of: paused, initial: true) { oldValue, newValue in
                        if newValue {
                            player.pause()
                        }  else {
                            player.play()
                        }
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
                
                VolumeBar(volume: $currentVolume)
                    .onChange(of: currentVolume, initial: true) { _, newValue in
                        player.volume = newValue
                    }
            }
        }
        
    }
}

#Preview {
    MusicPlayerView(presented: .constant(true), 
                    music: Music.examples()[0])
        .frame(width: 700, height: 600)
        .environmentObject(ArthubPlayer())
}
