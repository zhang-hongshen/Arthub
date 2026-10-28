//
//  VideoPlayerView.swift
//  Arthub
//
//  Created by 张鸿燊 on 10/3/2024.
//

import SwiftUI
import AVFoundation
import AVKit

/// A position within one item of the player's playlist.
private struct PlaybackPosition: Equatable {
    var index: Int
    var time: TimeInterval
}

/// How far playback moves between progress reports.
private let progressReportInterval: TimeInterval = 10

struct VideoPlayerView<SidebarContent: View, ControlsContent: View>: View {

    /// Where this view starts playback, or `nil` when the caller starts the player itself (e.g. an episode picker).
    var startTime: TimeInterval?
    /// Receives the playing item's index and position every few seconds of playback,
    /// and when playback pauses, moves to another item, or this view goes away.
    var onProgress: (_ index: Int, _ time: TimeInterval) -> Void
    var onTapOverlay: () -> Void
    var sidebarContent: () -> SidebarContent
    var controlsTrailingContent: () -> ControlsContent

    // Playback controls
    @State private var isHovering = false
    @State private var mouseIsMoving = false
    @State private var controlsHeight: CGFloat = 0
    @State private var currentVolume: Float = 0.5
    @State private var currentTime: TimeInterval
    @State private var seeking = false
    @State private var lastPosition: PlaybackPosition? = nil
    @State private var reportedPosition: PlaybackPosition? = nil
    // Preview image shown above the progress bar while hovering it
    @State private var previewTime: TimeInterval? = nil
    @State private var previewImage: CGImage? = nil
    @State private var previewImageOffsetX: CGFloat = 0
    @State private var progressBarFrame: CGRect = .zero
    @State private var videoAspectRatio: CGFloat = 16 / 9
    // Sidecar subtitles
    @State private var subtitles: [MediaNaming.Subtitle] = []
    @State private var selectedSubtitle: MediaNaming.Subtitle? = nil
    @State private var subtitleCues: [SubtitleCue] = []

    @Environment(\.dismiss) private var dismiss
    @Environment(ArthubVideoPlayer.self) private var player
    @Environment(WindowState.self) private var windowState
    @Environment(\.scenePhase) private var scenePhase

    #if canImport(AppKit)
    @State private var hideControlsTimer: Timer? = nil
    /// The mouse-moved monitor added on appear; it outlives the player unless removed on disappear.
    @State private var mouseMonitor: Any? = nil
    #endif

    private let previewImageHeight: CGFloat = 100
    private var controlsPresented: Bool { isHovering && mouseIsMoving }
    private var versions: [MediaVersion] { player.currentIndex.map { player.items[$0].versions } ?? [] }

    init(startTime: TimeInterval?, onProgress: @escaping (_ index: Int, _ time: TimeInterval) -> Void,
         onTapOverlay: @escaping () -> Void = {},
         @ViewBuilder sidebarContent: @escaping () -> SidebarContent = { EmptyView() },
         @ViewBuilder controlsTrailingContent: @escaping () -> ControlsContent = { EmptyView() }) {
        self.startTime = startTime
        self.onProgress = onProgress
        self._currentTime = State(initialValue: startTime ?? 0)
        self.onTapOverlay = onTapOverlay
        self.sidebarContent = sidebarContent
        self.controlsTrailingContent = controlsTrailingContent
    }

    var body: some View {
        VideoPlayer(player: player.player)
            .ignoresSafeArea()
            .overlay(alignment: .bottom) { SubtitleView() }
            .overlay {
                PlayerOverlayView()
                    .contentShape(.rect)
                    .onTapGesture(perform: onTapOverlay)
                    .simultaneousGesture(TapGesture(count: 2).onEnded(player.togglePlayPause))
            }
            .frame(minWidth: 350, minHeight: controlsHeight + previewImageHeight)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .automatic)
            .task {
                guard let startTime, player.playerState == .stopped else { return }
                player.start(at: startTime)
            }
            .task(id: player.currentAssetURL) {
                await loadSubtitles()
                await loadAspectRatio()
            }
            .task(id: selectedSubtitle) {
                guard let url = selectedSubtitle?.url else { subtitleCues = []; return }
                subtitleCues = await Task.detached { SidecarParser.subtitles(url: url) }.value
            }
            .onAppear(perform: onAppear)
            .onHover { isHovering = $0 }
            .onKeyPress(keys: [.leftArrow, .rightArrow, .space], action: handleKeyPress)
            .onChange(of: player.currentTime, initial: true) { _, newValue in
                // A stopped player reads 0, which must not replace the start position or the saved progress.
                guard player.playerState != .stopped else { return }
                if !seeking { currentTime = newValue }
                recordPosition(newValue)
            }
            .onChange(of: player.isPlaying) { _, isPlaying in
                if !isPlaying { reportCurrentPosition() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { reportCurrentPosition() }
            }
            #if os(macOS)
            // Quitting doesn't make this view disappear.
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                reportCurrentPosition()
            }
            #endif
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
            HStack {
                Button("Back", systemImage: "chevron.left", action: dismiss.callAsFunction)
                    .labelStyle(.iconOnly)
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
                        Color.clear.onAppear { controlsHeight = proxy.size.height }
                    }
                }
        }
        .safeAreaPadding()
        // SwiftUI drops fully transparent views from the accessibility tree, so the hidden controls
        // stay a hair above 0 for VoiceOver and agents, and ignore the mouse until they show.
        .opacity(controlsPresented ? 1 : 0.001)
        .allowsHitTesting(controlsPresented)
        .buttonStyle(.borderless)
        .overlay(alignment: .trailing) {
            sidebarContent()
                .safeAreaPadding(.top)
        }
    }

    @ViewBuilder
    func PlaybackControlView() -> some View {
        @Bindable var player = player

        VStack {
            ProgressBar()

            HStack {
                VolumeBar(volume: $currentVolume)
                    .onChange(of: currentVolume, initial: true) { player.volume = $1 }
                    .frame(minWidth: 100, maxWidth: 150)

                Spacer()

                Group {
                    Button("Skip Back 15 Seconds", systemImage: "gobackward.15") { player.skip(by: -15) }
                    Button(player.isPlaying ? "Pause" : "Play", systemImage: player.isPlaying ? "pause" : "play",
                           action: player.togglePlayPause)
                        .symbolVariant(.fill)
                    Button("Skip Forward 15 Seconds", systemImage: "goforward.15") { player.skip(by: 15) }
                }
                .labelStyle(.iconOnly)

                Spacer()

                controlsTrailingContent()

                if versions.count > 1 {
                    Menu {
                        Picker("Version", selection: Binding(get: { player.currentAssetURL },
                                                             set: { if let url = $0 { player.switchVersion(to: url) } })) {
                            ForEach(versions, id: \.fileURL) { version in
                                Text(verbatim: version.label).tag(Optional(version.fileURL))
                            }
                        }
                        .pickerStyle(.inline)
                    } label: {
                        Image(systemName: "rectangle.stack")
                    }
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .accessibilityLabel("Version")
                }

                if !subtitles.isEmpty {
                    Menu {
                        Picker("Subtitles", selection: $selectedSubtitle) {
                            Text("Off").tag(MediaNaming.Subtitle?.none)
                            ForEach(subtitles) { subtitle in
                                Text(subtitle.displayName).tag(Optional(subtitle))
                            }
                        }
                        .pickerStyle(.inline)
                    } label: {
                        Image(systemName: selectedSubtitle == nil ? "captions.bubble" : "captions.bubble.fill")
                    }
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .accessibilityLabel("Subtitles")
                }

                Picker("Playback Speed", selection: $player.playbackRate) {
                    ForEach(AVPlaybackSpeed.systemDefaultSpeeds, id: \.rate) { speed in
                        Text(speed.localizedNumericName).tag(speed.rate)
                    }
                }
                .labelsHidden()
                .menuIndicator(.hidden)
            }
            .font(.title2)
        }
    }

    @ViewBuilder
    func ProgressBar() -> some View {
        HStack {
            Text(currentTime.formatted())
            ArthubSlider(value: $currentTime, in: 0...player.duration) { isEditing in
                // Seek once the thumb is let go.
                if seeking && !isEditing {
                    player.seek(to: currentTime)
                }
                seeking = isEditing
            } onHoveringValueChanged: { time in
                showPreview(at: time)
            } onHoverEnded: {
                previewTime = nil
                previewImage = nil
            }
            .accessibilityLabel("Playback Position")
            .accessibilityValue(Text(verbatim: "\(currentTime.formatted()) / \(player.duration.formatted())"))
            .overlay {
                GeometryReader { proxy in
                    let frame = proxy.frame(in: .global)
                    Color.clear.onChange(of: frame, initial: true) { progressBarFrame = frame }
                }
            }
            Text(player.duration.formatted())
        }
    }

    @ViewBuilder
    func PreviewImageView() -> some View {
        if let previewImage, let previewTime {
            VStack {
                Image(previewImage, scale: 1, label: Text(previewTime.formatted()))
                    .resizable()
                    .frame(width: previewImageHeight * videoAspectRatio, height: previewImageHeight)
                    .cornerRadius()
                Text(previewTime.formatted())
            }
        }
    }
}

// MARK: Subtitles

extension VideoPlayerView {

    @ViewBuilder
    func SubtitleView() -> some View {
        if !subtitleCues.isEmpty {
            TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                let time = player.player.currentTime().seconds
                let text = subtitleCues.filter { $0.start <= time && time < $0.end }
                    .map(\.text).joined(separator: "\n")
                if !text.isEmpty {
                    Text(verbatim: text)
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .shadow(color: .black, radius: 2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.35), in: .rect(cornerRadius: 6))
                }
            }
            .padding(.horizontal)
            .padding(.bottom, controlsPresented ? controlsHeight + 24 : 48)
            .animation(.default, value: controlsPresented)
            .allowsHitTesting(false)
        }
    }

    /// Finds `Movie.srt`, `Movie.en.srt`, `Subs/…` next to the current item and picks a default.
    func loadSubtitles() async {
        guard let url = player.currentAssetURL else {
            subtitles = []
            selectedSubtitle = nil
            return
        }
        let found = await Task.detached { MediaNaming.subtitles(for: url) }.value
        subtitles = found
        // Switching versions keeps a subtitle the new version shares.
        if let selectedSubtitle, found.contains(selectedSubtitle) { return }
        selectedSubtitle = MediaNaming.preferredSubtitle(in: found)
    }
}

// MARK: Events

extension VideoPlayerView {

    func onAppear() {
        windowState.enterFullScreen()
        #if canImport(AppKit)
        // Show the controls while the mouse moves, and hide them and the pointer 5 seconds after it stops.
        guard mouseMonitor == nil else { return }
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { event in
            mouseIsMoving = true
            NSCursor.unhide()
            hideControlsTimer?.invalidate()
            hideControlsTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
                mouseIsMoving = false
                NSCursor.hide()
            }
            return event
        }
        #endif
    }

    func onDisappear() {
        reportCurrentPosition()
        #if canImport(AppKit)
        // Left in place, the monitor kept running after the player closed and its timer hid the pointer.
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        mouseMonitor = nil
        hideControlsTimer?.invalidate()
        NSCursor.unhide()
        #endif
        DispatchQueue.main.async {
            windowState.exitFullScreen()
            player.stop()
        }
    }

    func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        switch keyPress.key {
        case .leftArrow: player.skip(by: -15)
        case .rightArrow: player.skip(by: 15)
        case .space: player.togglePlayPause()
        default: break
        }
        return .handled
    }

    /// Shows a frame of the video above the progress bar, at the hovered time.
    func showPreview(at time: TimeInterval) {
        // Skip small mouse movements.
        if let previewTime, abs(previewTime - time) < 1 { return }
        previewTime = time

        let width = previewImageHeight * videoAspectRatio
        let x = progressBarFrame.minX + progressBarFrame.width * time / player.duration - width / 2
        previewImageOffsetX = x.clamp(to: 0...max(0, progressBarFrame.width - width / 2))

        guard let asset = player.player.currentItem?.asset else { return }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.generateCGImageAsynchronously(for: CMTime(seconds: time, preferredTimescale: 1)) { image, _, _ in
            DispatchQueue.main.async { previewImage = image }
        }
    }

    func loadAspectRatio() async {
        guard let asset = player.player.currentItem?.asset,
              let track = try? await asset.loadTracks(withMediaType: .video).first,
              let (size, transform) = try? await track.load(.naturalSize, .preferredTransform)
        else { return }
        let rotated = size.applying(transform)
        if rotated.height != 0 { videoAspectRatio = abs(rotated.width / rotated.height) }
    }
}

// MARK: Progress

extension VideoPlayerView {

    /// Remembers the playing position and reports it after every `progressReportInterval` seconds of movement.
    /// When the player moves to another item, the previous item's last position is reported first.
    private func recordPosition(_ time: TimeInterval) {
        guard let index = player.currentIndex, time.isFinite else { return }
        if let lastPosition, lastPosition.index != index, lastPosition != reportedPosition {
            report(lastPosition)
        }
        let position = PlaybackPosition(index: index, time: time)
        lastPosition = position
        if reportedPosition?.index != index ||
            abs(time - (reportedPosition?.time ?? 0)) >= progressReportInterval {
            report(position)
        }
    }

    /// Reports where playback is now, e.g. on pause or before this view goes away.
    private func reportCurrentPosition() {
        if player.playerState != .stopped, let index = player.currentIndex {
            let time = player.player.currentTime().seconds
            if time.isFinite { lastPosition = PlaybackPosition(index: index, time: time) }
        }
        guard let lastPosition, lastPosition != reportedPosition else { return }
        report(lastPosition)
    }

    private func report(_ position: PlaybackPosition) {
        reportedPosition = position
        onProgress(position.index, position.time)
    }
}
