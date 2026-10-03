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
            }

            Button(action: player.previousTrack) {
                Image(systemName: "backward.fill").font(.title3)
            }
            .disabled(player.isPlaylistEmpty)

            Button {
                player.isPlaylistEmpty ? onStartPlayback() : player.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 28)
            }

            Button(action: player.nextTrack) {
                Image(systemName: "forward.fill").font(.title3)
            }
            .disabled(player.isPlaylistEmpty)

            if showsSecondaryControls {
                Button(action: player.nextPlayerMode) {
                    Image(systemName: player.playerMode == .repeatItem ? "repeat.1" : "repeat")
                }
                .foregroundStyle(player.playerMode == .noRepeat ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
                .help("Repeat")
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
            ArtworkImage(data: song?.album.cover, aspectRatio: 1, contentMode: .fill) {
                Image(systemName: "music.note")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.quaternary)
            }
            .frame(width: artworkSize, height: artworkSize)
            .cornerRadius(6)
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpenPlayer)
            .help("Open Player")

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

                MiniProgressBar(currentTime: player.currentTime,
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

            DevicePickerView(player: player.player)
                .frame(width: 22, height: 22)

            VolumeButton()
        }
        .font(.title3)
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
        .popover(isPresented: $popoverPresented, arrowEdge: .top) {
            Slider(value: Binding(get: { player.volume },
                                  set: { player.volume = $0 }),
                   in: 0...1)
                .frame(width: 160)
                .padding()
        }
    }
}

// MARK: Progress

fileprivate struct MiniProgressBar: View {

    var currentTime: TimeInterval
    var duration: TimeInterval
    var onSeek: (TimeInterval) -> Void

    @State private var dragProgress: Double? = nil
    @State private var isHovering = false

    private var progress: Double {
        if let dragProgress { return dragProgress }
        guard duration > 0 else { return 0 }
        return (currentTime / duration).clamp(to: 0...1)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.15))
                Capsule().fill(.primary.opacity(isHovering ? 0.8 : 0.5))
                    .frame(width: width * progress)
            }
            .frame(height: isHovering || dragProgress != nil ? 5 : 3)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard duration > 0, width > 0 else { return }
                        dragProgress = (value.location.x / width).clamp(to: 0...1)
                    }
                    .onEnded { _ in
                        if let dragProgress { onSeek(dragProgress * duration) }
                        dragProgress = nil
                    }
            )
        }
        .frame(height: 8)
        #if os(macOS)
        .onHover { isHovering = $0 }
        #endif
        .animation(.snappy(duration: 0.2), value: isHovering)
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
                .overlay { Capsule().strokeBorder(.white.opacity(0.1)) }
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
