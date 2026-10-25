//
//  MiniMusicPlayer.swift
//  Arthub
//
//  Created by 张鸿燊 on 3/10/2026.
//

import SwiftUI

/// Floating now-playing bar modelled on Apple Music's bottom player:
/// transport controls, artwork with title and progress, then lyrics / AirPlay / volume.
struct MiniMusicPlayer: View {

    var song: Song?
    var lyricsPresented: Bool
    var onToggleLyrics: () -> Void
    var onOpenPlayer: () -> Void
    /// Called when play is pressed with nothing queued.
    var onStartPlayback: () -> Void

    @Environment(ArthubAudioPlayer.self) private var player

    private let artworkSize: CGFloat = 40

    var body: some View {
        HStack(spacing: 18) {
            TransportControls()
            NowPlayingView()
            AccessoryControls()
        }
        .buttonStyle(.borderless)
        .padding(.leading, 20)
        .padding(.trailing, 16)
        .padding(.vertical, 8)
        .glassCapsule()
        .frame(maxWidth: 760)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

// MARK: Transport

extension MiniMusicPlayer {

    @ViewBuilder
    func TransportControls() -> some View {
        HStack(spacing: 14) {
            if showsSecondaryControls {
                Button(action: player.toggleShuffle) {
                    Image(systemName: "shuffle")
                }
                .foregroundStyle(player.shuffled ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .help("Shuffle")
                .accessibilityLabel("Shuffle")
                .accessibilityAddTraits(player.shuffled ? .isSelected : [])
            }

            Button(action: player.previousTrack) {
                Image(systemName: "backward.fill").font(.title3)
            }
            .disabled(player.isPlaylistEmpty)
            .accessibilityLabel("Previous")

            Button {
                player.isPlaylistEmpty ? onStartPlayback() : player.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 28)
            }
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

            Button(action: player.nextTrack) {
                Image(systemName: "forward.fill").font(.title3)
            }
            .disabled(player.isPlaylistEmpty)
            .accessibilityLabel("Next")

            if showsSecondaryControls {
                Button(action: player.nextPlayerMode) {
                    Image(systemName: player.playerMode == .repeatItem ? "repeat.1" : "repeat")
                }
                .foregroundStyle(player.playerMode == .noRepeat ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
                .help("Repeat")
                .accessibilityLabel("Repeat")
                .accessibilityValue(player.playerMode.accessibilityValue)
            }
        }
        .foregroundStyle(.primary)
    }

    private var showsSecondaryControls: Bool {
        #if os(iOS)
        !UIDevice.isIPhone
        #else
        true
        #endif
    }
}

// MARK: Now Playing

extension MiniMusicPlayer {

    @ViewBuilder
    func NowPlayingView() -> some View {
        HStack(spacing: 10) {
            MiniArtwork(cover: song?.album.cover, size: artworkSize, onOpenPlayer: onOpenPlayer)

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: song?.title ?? "")
                        .font(.callout.weight(.semibold))
                    Text(verbatim: subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .fixedSize()
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                .fadingTruncation()

                Spacer(minLength: 0)

                PlaybackProgressBar(currentTime: player.currentTime,
                                duration: player.duration,
                                onSeek: player.seek(to:))
                    .disabled(song == nil)
            }
            .frame(height: artworkSize)
        }
        .frame(minWidth: 160, maxWidth: .infinity)
    }

    private var subtitle: String {
        guard let song else { return "" }
        return [song.artist.name, song.album.title]
            .filter { !$0.isEmpty }
            .joined(separator: " — ")
    }
}

// MARK: Accessories

extension MiniMusicPlayer {

    @ViewBuilder
    func AccessoryControls() -> some View {
        HStack(spacing: 14) {
            Button(action: onToggleLyrics) {
                Image(systemName: "quote.bubble")
                    .symbolVariant(lyricsPresented ? .fill : .none)
            }
            .foregroundStyle(lyricsPresented ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
            .help("Lyrics")
            .accessibilityLabel("Lyrics")
            .accessibilityAddTraits(lyricsPresented ? .isSelected : [])

            DevicePickerView(player: player.player)
                .frame(width: 22, height: 22)

            VolumeButton()
        }
        .font(.title3)
    }
}

/// Artwork that grows slightly under the pointer and reveals an expand button for the full player.
fileprivate struct MiniArtwork: View {

    var cover: Data?
    var size: CGFloat
    var onOpenPlayer: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onOpenPlayer) {
            ArtworkImage(data: cover, aspectRatio: 1, contentMode: .fill) {
                Image(systemName: "music.note")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.surface)
            }
            .frame(width: size, height: size)
            .overlay {
                if isHovering {
                    ZStack {
                        Color.black.opacity(0.35)
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: size * 0.4, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2)
                    }
                    .transition(.opacity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(isHovering ? 0.25 : 0), radius: 4, y: 2)
            .scaleEffect(isHovering ? 1.1 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Open Player")
        .accessibilityLabel("Open Player")
        #if os(macOS)
        .onHover { isHovering = $0 }
        #endif
        .animation(.snappy(duration: 0.2), value: isHovering)
    }
}

fileprivate struct VolumeButton: View {

    @Environment(ArthubAudioPlayer.self) private var player
    @State private var popoverPresented = false

    var body: some View {
        Button {
            popoverPresented.toggle()
        } label: {
            Image(systemName: player.volume == 0 ? "speaker.slash.fill" : "speaker.wave.3.fill",
                  variableValue: Double(player.volume))
                .frame(width: 26, alignment: .leading)
        }
        .help("Volume")
        .accessibilityLabel("Volume")
        .accessibilityValue(Double(player.volume).formatted(.percent.precision(.fractionLength(0))))
        .popover(isPresented: $popoverPresented, arrowEdge: .top) {
            Slider(value: Binding(get: { player.volume },
                                  set: { player.volume = $0 }),
                   in: 0...1)
                .accessibilityLabel("Volume")
                .frame(width: 160)
                .padding()
        }
    }
}

// MARK: Progress

/// A thin bar that thickens under the pointer; click or drag it to seek. `MusicPlayer` shows a thicker one.
struct PlaybackProgressBar: View {

    var currentTime: TimeInterval
    var duration: TimeInterval
    var thickness: CGFloat = 3
    /// The time being dragged to, and nil once the drag ends.
    var onScrub: (TimeInterval?) -> Void = { _ in }
    var onSeek: (TimeInterval) -> Void

    @State private var dragProgress: Double? = nil
    @State private var isHovering = false

    private var progress: Double {
        if let dragProgress { return dragProgress }
        guard duration > 0 else { return 0 }
        return (currentTime / duration).clamp(to: 0...1)
    }

    private var expandedThickness: CGFloat { thickness * 5 / 3 }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.15))
                Capsule().fill(.primary.opacity(isHovering ? 0.8 : 0.5))
                    .frame(width: width * progress)
            }
            .frame(height: isHovering || dragProgress != nil ? expandedThickness : thickness)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard duration > 0, width > 0 else { return }
                        let fraction = (value.location.x / width).clamp(to: 0...1)
                        dragProgress = fraction
                        onScrub(fraction * duration)
                    }
                    .onEnded { _ in
                        if let dragProgress { onSeek(dragProgress * duration) }
                        dragProgress = nil
                        onScrub(nil)
                    }
            )
        }
        .frame(height: expandedThickness + 3)
        #if os(macOS)
        .onHover { isHovering = $0 }
        #endif
        .animation(.snappy(duration: 0.2), value: isHovering)
        .accessibilityElement()
        .accessibilityLabel("Playback Position")
        .accessibilityValue(Text(verbatim: "\(currentTime.formatted()) / \(duration.formatted())"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onSeek(min(currentTime + 10, duration))
            case .decrement: onSeek(max(currentTime - 10, 0))
            @unknown default: break
            }
        }
    }
}

extension ArthubPlayer.PlayerMode {

    /// What the repeat button reads out, since its icon alone tells "all" from "one".
    var accessibilityValue: LocalizedStringKey {
        switch self {
        case .noRepeat: "Off"
        case .repeatPlaylist: "Repeat All"
        case .repeatItem: "Repeat One"
        }
    }
}

// MARK: Styling

fileprivate extension View {

    @ViewBuilder
    func glassCapsule() -> some View {
        if #available(macOS 26.0, iOS 26.0, tvOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            self.background(.regularMaterial, in: Capsule())
                .overlay { Capsule().strokeBorder(.primary.opacity(0.1)) }
                .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
        }
    }

    /// Fades text out at the trailing edge instead of showing an ellipsis.
    func fadingTruncation() -> some View {
        self.mask {
                LinearGradient(stops: [.init(color: .black, location: 0.85),
                                       .init(color: .black.opacity(0), location: 1)],
                               startPoint: .leading, endPoint: .trailing)
            }
    }
}

#Preview {
    MiniMusicPlayer(song: nil, lyricsPresented: false,
                    onToggleLyrics: {}, onOpenPlayer: {}, onStartPlayback: {})
        .environment(ArthubAudioPlayer())
        .padding(.top, 40)
}
