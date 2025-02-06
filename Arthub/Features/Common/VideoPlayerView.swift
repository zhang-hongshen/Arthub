//
//  VideoPlayerView.swift
//  Arthub
//
//  Created by 张鸿燊 on 10/3/2024.
//

import SwiftUI
import AVFoundation
import AVKit

struct VideoPlayerView<SidebarContent, ControlsContent>: View
        where SidebarContent: View, ControlsContent: View {
    
    @Binding var currentTime: TimeInterval
    var onTapOverlay: () -> Void
    var sidebarContent: () -> SidebarContent
    var controlsTrailingContent: () -> ControlsContent
    
    enum PlayerSettingsTab: Identifiable {
        case video, audio
        var id: Self { self }
    }
    
    // playback control
    @State private var isHovering = false
    @State private var mouseIsMoving = false
    private var playerOverlayPresented: Bool {
        isHovering && mouseIsMoving
    }
    @State private var settingsPresented: Bool = false
    @State private var playbackControlMinSize: CGSize = .init(width: 350, height: .zero)
    @State private var currentVolume: Float = 0.5
    @State private var seeking: Bool = false
    // Preview Image
    @State private var previewTime: TimeInterval? = nil
    @State private var previewImage: CGImage? = nil
    @State private var previewImageOffsetX: CGFloat = .zero
    @State private var playbackCoordinate: CGRect = .zero
    @State private var previewImageSize: CGSize = .init(width: .zero, height: 100)
    @State private var currentResolution: VideoResolution? = nil
    @State private var selectedTab: PlayerSettingsTab = .video
    
    @Environment(\.dismiss) private var dismiss
    @Environment(ArthubVideoPlayer.self) private var player
    @Environment(WindowState.self) private var windowState
    
    @State private var timer: Timer? = nil
    
    private var frameMinSize: CGSize {
        .init(width: playbackControlMinSize.width,
              height: playbackControlMinSize.height + previewImageSize.height)
    }
    
    public init(currentTime: Binding<TimeInterval>, onTapOverlay: @escaping () -> Void = {},
                @ViewBuilder sidebarContent: @escaping () -> SidebarContent = { EmptyView() },
                @ViewBuilder controlsTrailingContent: @escaping () -> ControlsContent = { EmptyView() }) {
        self._currentTime = currentTime
        self.onTapOverlay = onTapOverlay
        self.sidebarContent = sidebarContent
        self.controlsTrailingContent = controlsTrailingContent
    }
    
    var body: some View {
        VideoPlayer(player: player.player)
            .ignoresSafeArea()
            .overlay {
                PlayerOverlayView()
                    .contentShape(.rect)
                    .onTapGesture{
                        settingsPresented = false
                        onTapOverlay()
                    }
                    .simultaneousGesture(TapGesture(count: 2).onEnded(player.togglePlayPause))
            }
            .frame(minWidth: frameMinSize.width,
                   minHeight: frameMinSize.height)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .automatic)
            .task {
                do { try await player.start(at: currentTime) }
                catch {}
            }
            .onAppear(perform: onAppear)
            .onHover(perform: { isHovering = $0 })
            .onKeyPress(keys: [.leftArrow, .rightArrow, .space], action: handleKeyPress)
            .onChange(of: player.currentTime, initial: true) { _, newValue in
                if !seeking {
                    currentTime  = newValue
                }
            }
            .onChange(of: player.currentVideoSize, initial: true) { _, newValue in
                guard let newValue else { return  }
                currentResolution = VideoResolution(size: newValue)
            }
            #if os(macOS) || os(tvOS)
            .onExitCommand(perform: dismiss.callAsFunction)
            #endif
            .onDisappear(perform: onDisappear)
            
    }
}

// MARK: Player Overlay

extension VideoPlayerView {
    
    @ViewBuilder
    func PlayerOverlayView() -> some View {
        
        VStack(alignment: .leading) {
            
            HStack(alignment: .center) {
                Button("", systemImage: "chevron.left", action: dismiss.callAsFunction)
                Spacer()
            }
            .imageScale(.large)
            .padding()
            .background(.ultraThinMaterial)
            
            
            Spacer()
            
            PreviewImageView()
                .offset(x: previewImageOffsetX)
            
            PlaybackControlView()
                .overlay {
                    GeometryReader { proxy in
                        Color.clear.task {
                            playbackControlMinSize.height = proxy.size.height
                        }
                    }
                }
        }
        .safeAreaPadding()
        .opacity(playerOverlayPresented ? 1 : 0)
        .transition(.opacity)
        .buttonStyle(.borderless)
        .overlay(alignment: .trailing) {
            Group {
                PlayerSettingsView()
                    .background(.ultraThinMaterial)
                    .frame(width: 300)
                    .offset(x: settingsPresented ? 0 : 300)
                    .opacity(settingsPresented ? 1 : 0)
                
                sidebarContent()
            }
            .safeAreaPadding(.top)
        }
    }
    
    @ViewBuilder
    func PlaybackControlView() -> some View {
        
        VStack(alignment: .center) {
            
            ProgressBar()
            
            HStack(alignment: .center)  {
                VolumeBar(volume: $currentVolume)
                    .onChange(of: currentVolume, initial: true, { player.volume = $1 })
                    .frame(minWidth: 100, maxWidth: 150)
                
                Spacer()
                
                Button("", systemImage: "gobackward.15", action: { player.skipBackward(by: 15) })
                Button("", systemImage: player.isPlaying ? "pause" : "play", action: player.togglePlayPause)
                    .symbolVariant(.fill)
                Button("", systemImage: "goforward.15", action: {player.skipForward(by: 15)})
                
                Spacer()
                
                controlsTrailingContent()
                
                Group {
                    if currentResolution != nil {
                        Picker("", selection: $currentResolution) {
                            ForEach(player.videoSizeOptions.map { VideoResolution(size: $0) }) { resolution in
                                Text(resolution.localizedName).tag(resolution as VideoResolution?)
                            }
                        }
                    }
                    
                    Picker("", selection: Binding(
                        get: { player.rate },
                        set: { player.setPlaybackRate($0) }
                    )) {
                        ForEach(AVPlaybackSpeed.systemDefaultSpeeds, id: \.rate) { speed in
                            Text(speed.localizedNumericName).tag(speed)
                        }
                    }
                }
                .menuIndicator(.hidden)
                Button("", systemImage: "ellipsis", action: {settingsPresented.toggle()})
            }
            .font(.title2)
        }
    }
    
    @ViewBuilder
    func ProgressBar() -> some View {
        HStack(alignment: .center) {
            Text(currentTime.formatted())
            ArthubSlider(value: $currentTime,
                            in: 0...player.duration) { newValue in
                if seeking && !newValue {
                    player.seek(to: currentTime)
                }
                seeking = newValue
            } onHoveringValueChanged: { newValue in
                handlePreviewTimeChange(oldValue: previewTime, newValue: newValue)
                previewTime = newValue
            } onHoverEnded: {
                handlePreviewTimeChange(oldValue: previewTime, newValue: nil)
                previewTime = nil
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
            .onPreferenceChange(PlaybackCoordinatePreference.self) { value in
                playbackCoordinate = value
            }
            
            Text(player.duration.formatted())
        }
    }
    
    @ViewBuilder
    func PreviewImageView() -> some View {
        if let previewImage = previewImage,
           let previewTime = previewTime {
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
}

// MARK: Player Settings

extension VideoPlayerView {
    
    @ViewBuilder
    func PlayerSettingsView() -> some View {
        TabView(selection: $selectedTab) {
            VideoSettingsView().tag(PlayerSettingsTab.video)
                .tabItem {
                    Image(systemName: "video")
                    Text("Video")
                }
            AudioSettingsView().tag(PlayerSettingsTab.audio)
                .tabItem {
                    Image(systemName: "waveform")
                    Text("Audio")
                }
        }
        .autoSize()
    }
    
    @ViewBuilder
    func VideoSettingsView() -> some View {
        VideoTrackSection()
    }
    
    @ViewBuilder
    func VideoTrackSection() -> some View {
        Section {
            
        } header: {
            Text("Video Track")
                .font(.title.bold())
        }
    }
    
    @ViewBuilder
    func AudioSettingsView() -> some View {
        AudioTrackSection()
    }
    
    @ViewBuilder
    func AudioTrackSection() -> some View {
        Section {
            
        } header: {
            Text("Audio Track")
                .font(.title.bold())
        }
    }
}



private struct PlaybackCoordinatePreference: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

extension VideoPlayerView {
    
    func onAppear() {
        windowState.enterFullScreen()
        #if canImport(AppKit)
        NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { event in
            mouseIsMoving = true
            NSCursor.unhide()
            if let timer {
                timer.invalidate()
                self.timer = nil
            }
            timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
                mouseIsMoving = false
                NSCursor.hide()
            }
            return event
        }
        #endif
    }
    
    func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        switch keyPress.key {
        case .leftArrow: player.skipBackward(by: 15)
        case .rightArrow: player.skipForward(by: 15)
        case .space: player.togglePlayPause()
        default: break
        }
        return .handled
    }
    
    func handlePreviewTimeChange(oldValue: TimeInterval?, newValue: TimeInterval?) {
        guard let newPreviewTime = newValue else {
            previewImage = nil
            return
        }
        if let oldPreviewTime = oldValue,
            abs(oldPreviewTime - newPreviewTime) < 1 {
            return
        }
        
        previewImageSize.width = previewImageSize.height * player.aspectRatio
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
    
    func onDisappear() {
        DispatchQueue.main.async {
            windowState.exitFullScreen()
            player.optOut()
        }
    }
}
