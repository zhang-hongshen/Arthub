//
//  MoviePlayerView.swift
//  Arthub
//
//  Created by 张鸿燊 on 1/2/2024.
//

import SwiftUI
import AVFoundation
import Logging

struct MoviePlayerView: View {
    
    @State var title: String
    @Binding var urls: [URL]
    @Binding var metrics: MovieMetrics
    
    @EnvironmentObject private var player: ArthubVideoPlayer
    @Environment(\.presentationMode) private var presentationMode
    @Environment(WindowState.self) private var windowState
    
    @State var groupedURL: [DisplayResolution: URL] = [:]
    @State var selectedURL: URL? = nil
    var playbackSpeed: [Float] = [0.5, 1.0, 1.5, 2.0, 4.0]
    // playback control
    @State var playbackControlPresented: Bool = false
    @State var playbackControlMinSize: CGSize = .init(width: 350, height: .zero)
    @State var currentVolume: Float = 0.5
    @State var previewTime: TimeInterval? = nil
    @State var previewImage: CGImage? = nil
    @State var previewImageOffsetX: CGFloat = .zero
    @State var playbackCoordinate: CGRect = .zero
    @State var previewImageSize: CGSize = .init(width: .zero, height: 100)
    @State var settingsPresented: Bool = false
    // detect user's seek
    @State var seeking: Bool = false
    
    var body: some View {
        PlayerView()
            .overlay {
                PlayerOverlayView()
                    .safeAreaPadding(.horizontal, 20)
                    .safeAreaPadding(.vertical, 10)
                    .contentShape(.rect)
                    .onTapGesture {
                        player.isPlaying ? player.pause() : player.play()
                    }
            }
            .frame(minWidth: playbackControlMinSize.width,
                   minHeight: playbackControlMinSize.height)
            .navigationTitle(title)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .windowToolbar)
            .inspector(isPresented: $settingsPresented) {
                PlayerSettingsView()
                    .animation(.easeInOut, value: settingsPresented)
            }
            .onHover { hovering in
                playbackControlPresented = hovering
            }
            .onAppear {
                windowState.setColumnVisibility(.detailOnly)
            }
            .task(priority: .userInitiated) {
                do {
                    try await initPlayer()
                } catch {
                    Logger.shared.error("initPlayer error, \(error.localizedDescription)")
                }
            }
    }
    
    func initPlayer() async throws {
        for url in urls {
            let tracks = try await AVURLAsset(url: url).loadTracks(withMediaType: .video)
            guard let track = tracks.first else{
                continue
            }
            groupedURL[try await track.load(.naturalSize).toDisplayResolution()] = url
        }
        selectedURL = groupedURL.first?.value
        guard let url = selectedURL else {
            return
        }
        try await player.start(url: url, startTime: metrics.currentTime)
    }
    
    func audible(url: URL) async throws {
        let asset = AVURLAsset(url: url)
        for characteristic in try await asset.load(.availableMediaCharacteristicsWithMediaSelectionOptions) {
            debugPrint("\(characteristic)")
            // Retrieve the AVMediaSelectionGroup for the specified characteristic.
            if let group = try await asset.loadMediaSelectionGroup(for: characteristic) {
                // Print its options.
                for option in group.options {
                    debugPrint("Option: \(option.displayName)")
                }
            }
        }
    }
}

extension MoviePlayerView {
    
    @ViewBuilder
    func PlayerView() -> some View {
        VideoPlayer(player: player.player)
            .animation(.smooth, value: selectedURL)
            .onChange(of: player.currentTime, initial: true) { _, newValue in
                if !seeking {
                    metrics.currentTime  = newValue
                }
            }
            .onChange(of: selectedURL, initial: false) { _, newValue in
                guard let url = newValue else {
                    return
                }
                Task(priority: .userInitiated) {
                    try await player.replace(url: url, startTime: metrics.currentTime)
                }
            }
            .onChange(of: previewTime, initial: true) { oldValue, newValue in
                guard let newPreviewTime = newValue else {
                    return
                }
                if let oldPreviewTime = oldValue,
                    abs(oldPreviewTime - newPreviewTime) < 1 {
                    return
                }
                
                previewImageSize.width = previewImageSize.height * player.ratio
                let previewProgress = newPreviewTime / player.duration
                previewImageOffsetX = playbackCoordinate.minX +
                playbackCoordinate.width * previewProgress - previewImageSize.width / 2
                let  previewImageOffsetMaxX = playbackCoordinate.width - previewImageSize.width / 2
                previewImageOffsetX =  previewImageOffsetX.clamp(to: 0...previewImageOffsetMaxX)
                
                player.generateImage(for: newPreviewTime) { image in
                    DispatchQueue.main.async {
                        previewImage = image
                    }
                }
            }
    }
    
    @ViewBuilder
    func PlayerOverlayView() -> some View {
        VStack(alignment: .leading) {
            
            HStack(alignment: .top) {
                Button {
                    exit()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.largeTitle)
                }
                .opacity(playbackControlPresented ? 1 : 0)
                .cursor()
                .keyboardShortcut(.escape, modifiers: [])
                
                Spacer()
            }
            
            Spacer()
            
            PreviewImageView()
                .offset(x: previewImageOffsetX)
            
            PlaybackControlView()
                .opacity(playbackControlPresented ? 1 : 0)
                .frame(minWidth: playbackControlMinSize.width)
                .overlay {
                    GeometryReader {proxy in
                        Color.clear.onAppear {
                            playbackControlMinSize.height = proxy.size.height
                        }
                    }
                }
        }
        .buttonStyle(.borderless)
    }
    
    @ViewBuilder
    func PreviewImageView() -> some View {
        if let previewImage = previewImage,
           let previewTime = previewTime{
            VStack(alignment: .center) {
                Image(previewImage, scale: 1, label: Text(previewTime.formatted()))
                    .resizable()
                    .frame(width: previewImageSize.width,
                           height: previewImageSize.height)
                    .scaledToFit()
                    .cornerRadius()
                Text(previewTime.formatted())
            }
        }
    }
    
    @ViewBuilder
    func PlaybackControlView() -> some View {
        VStack(alignment: .leading) {
            
            HStack(alignment: .center) {
                Text(metrics.currentTime.formatted())
                ArthubSlider(value: $metrics.currentTime,
                             in: 0...player.duration) { newValue in
                    if seeking && !newValue {
                        player.seek(to: metrics.currentTime)
                    }
                    seeking = newValue
                } onHoveringValueChanged: { newValue in
                    previewTime = newValue
                } onHoverEnded: {
                    previewTime = nil
                    previewImage = nil
                }
                .overlay {
                    GeometryReader { proxy in
                        Color.clear
                            .preference(
                                key: PlaybackCoordinatePreference.self,
                                value: proxy.frame(in: .global)
                              )
                    }
                }
                
                Text(player.duration.formatted())
            }
            .onPreferenceChange(PlaybackCoordinatePreference.self) { value in
                playbackCoordinate = value
            }
            
            HStack {
                VolumeBar(volume: $currentVolume)
                    .onChange(of: currentVolume, initial: true) { _, newValue in
                    player.setVolume(newValue)
                }
                .frame(width: 150)
                .alignmentGuide(HorizontalAlignment.trailing) { _ in 0 }
                
                Spacer()
                
                HStack(alignment: .center) {
                    Button {
                        player.seek(to: player.currentTime - 15)
                    } label: {
                        Image(systemName: "gobackward.15")
                    }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                    
                    Button {
                        player.isPlaying ? player.pause() : player.pause()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    } 
                    .keyboardShortcut(.space, modifiers: [])
                    
                    Button {
                        player.seek(to: player.currentTime + 15)
                    } label: {
                        Image(systemName: "goforward.15")
                    }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                }
                .alignmentGuide(HorizontalAlignment.trailing) { -$0.width / 2 }
                
                Spacer()
                
                Picker("", selection: $player.rate) {
                    ForEach(playbackSpeed, id: \.self) { speed in
                        Text("\(speed.formatted())x").tag(speed)
                    }
                }
                
                Picker("", selection: $selectedURL) {
                    ForEach(groupedURL.keys.sorted{ $0.rawValue < $1.rawValue }) { k in
                        Text(k.rawValue).tag(groupedURL[k])
                    }
                }
                
                Button {
                    settingsPresented.toggle()
                } label: {
                    Image(systemName: "ellipsis")
                }
                .alignmentGuide(HorizontalAlignment.trailing) { $0[.trailing] - $0.width }
            }
            .font(.title2)
        }
    }
}

extension MoviePlayerView {
    
    @ViewBuilder
    func PlayerSettingsView() -> some View {
        
    }
}

extension MoviePlayerView {
    
    func exit() {
        if !player.isDurationValid() {
            metrics.setProgress(metrics.currentTime / player.duration)
        }
        player.stop()
        self.presentationMode.wrappedValue.dismiss()
        windowState.pop()
    }
    
}

private struct PlaybackCoordinatePreference: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

#Preview {
    MoviePlayerView(title: "1231",
                    urls: .constant([]),
                    metrics: .constant(MovieDetail.examples()[0].metrics))
        .frame(width: 600, height: 500)
}
