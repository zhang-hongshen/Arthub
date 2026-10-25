//
//  MusicPlayer.swift
//  Arthub
//
//  Created by 张鸿燊 on 1/2/2024.
//

import SwiftUI
import AVFoundation
import CoreImage

/// Full-window now playing modelled on Apple Music: artwork, details and controls on the left,
/// lyrics on the right, over a blur of the artwork itself.
struct MusicPlayer: View {

    var currentSong: Song?

    @State private var lyricsPresented: Bool = true
    @State private var backdrop: CGImage? = nil
    @State private var quality: AudioQuality? = nil

    @Environment(ArthubAudioPlayer.self) private var player
    @Environment(WindowState.self) private var windowState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private let frameMinSize = CGSize(width: 600, height: 450)

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width < 700 {
                CompactLayout(proxy.size)
            } else {
                RegularLayout(proxy.size)
            }
        }
        .animation(.snappy, value: lyricsPresented)
        .background { Backdrop() }
        .frame(minWidth: frameMinSize.width,
               minHeight: frameMinSize.height)
        .navigationTitle("")
        .navigationBarBackButtonHidden()
        .toolbar { ToolbarItems() }
        .toolbarBackground(.clear.opacity(0), for: .automatic)
        #if os(iOS)
        .toolbar(.hidden, for: .tabBar)
        #endif
        #if canImport(AppKit)
        .hideToolbarWhenFullscreen()
        #endif
        .task(id: currentSong?.id) { await loadSongDetails() }
        .onAppear(perform: windowState.enterFullScreen)
        .onDisappear(perform: windowState.exitFullScreen)
    }

    /// The backdrop and the quality badge are read from the song once.
    private func loadSongDetails() async {
        guard let song = currentSong else {
            backdrop = nil
            quality = nil
            return
        }
        let cover = song.album.cover
        backdrop = await Task.detached(priority: .userInitiated) {
            cover.flatMap { CIImage(data: $0) }?.backdrop()
        }.value
        quality = await AudioQuality(url: song.fileURL)
    }
}

// MARK: Toolbar

extension MusicPlayer {

    @ToolbarContentBuilder
    func ToolbarItems() -> some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button("Close", systemImage: "xmark") { dismiss() }
                .keyboardShortcut(.cancelAction)
                .help("Close")
        }

        ToolbarItem(placement: .primaryAction) {
            VolumeControl()
        }
    }
}

// MARK: Background

extension MusicPlayer {

    /// The artwork stretched over the window and blurred, so its colours sit where they are on the cover.
    @ViewBuilder
    func Backdrop() -> some View {
        let isDark = colorScheme == .dark
        ZStack {
            Color.playerBackground
            if let backdrop {
                Image(decorative: backdrop, scale: 1)
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
                    .transition(.opacity)
                    .id(backdrop)
            }
            // Keeps white text readable over light artwork, and black text over dark artwork.
            isDark ? Color.black.opacity(0.3) : Color.white.opacity(0.5)
        }
        .animation(.easeInOut(duration: 0.8), value: backdrop)
        .ignoresSafeArea()
    }
}

// MARK: Layout

extension MusicPlayer {

    /// The player column centred in the left half, lyrics in the right; the column centres in the window
    /// without lyrics.
    @ViewBuilder
    func RegularLayout(_ size: CGSize) -> some View {
        // Three quarters of its half, as far as the height leaves room for the artwork.
        let width = max(min(size.width / 2 * 0.76, (size.height - 230) / 0.88, 560), 200)
        HStack(spacing: 0) {
            PlayerColumn(width: width)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if lyricsPresented {
                LyricsInspectorView(song: currentSong,
                                    style: .player(fontSize: (size.width * 0.03).clamp(to: 24...44)))
                    .padding(.trailing, 32)
                    // Clear of the buttons in the corner.
                    .padding(.bottom, 64)
                    .frame(maxWidth: .infinity)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottomTrailing) {
            AccessoryControls().padding(16)
        }
    }

    /// One column: the artwork, or a small one above the lyrics, with the controls below.
    @ViewBuilder
    func CompactLayout(_ size: CGSize) -> some View {
        let width = min(size.width - 48, 520)
        let scale = width / 360
        VStack(spacing: 0) {
            if lyricsPresented {
                HStack(spacing: 12) {
                    CoverArt(size: 56 * scale)
                    InfoRow(scale: scale)
                }
                .padding(.top, 12)

                LyricsInspectorView(song: currentSong,
                                    style: .player(fontSize: (size.width * 0.065).clamp(to: 22...30)))
                    .frame(maxHeight: .infinity)
            } else {
                StageArtwork(size: max(min(width, size.height - 300 * scale), 80))
                    .frame(maxHeight: .infinity)

                InfoRow(scale: scale)
            }

            PlaybackProgress(isEnabled: currentSong != nil, quality: quality, scale: scale)
                .padding(.top, 22 * scale)

            TransportControls(scale: scale)
                .padding(.vertical, 22 * scale)

            AccessoryControls()
                .padding(.bottom, 12)
        }
        .frame(width: width)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    func PlayerColumn(width: CGFloat) -> some View {
        let scale = width / 360
        VStack(spacing: 0) {
            StageArtwork(size: width * 0.88)
                .padding(.bottom, 24 * scale)

            InfoRow(scale: scale)
                .padding(.bottom, 22 * scale)

            PlaybackProgress(isEnabled: currentSong != nil, quality: quality, scale: scale)
                .padding(.bottom, 22 * scale)

            TransportControls(scale: scale)
        }
        .frame(width: width)
    }
}

// MARK: Artwork and Details

extension MusicPlayer {

    @ViewBuilder
    func CoverArt(size: CGFloat) -> some View {
        ArtworkImage(data: currentSong?.album.cover, aspectRatio: 1, contentMode: .fill) {
            Image(systemName: "music.note")
                .font(.system(size: size * 0.3))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.surface)
        }
        .frame(width: size, height: size)
        .cornerRadius(size * 0.035)
    }

    /// The artwork steps back while paused and comes forward again on play, as in Apple Music.
    @ViewBuilder
    func StageArtwork(size: CGFloat) -> some View {
        CoverArt(size: size)
            .shadow(color: .black.opacity(0.35),
                    radius: player.isPlaying ? 30 : 12,
                    y: player.isPlaying ? 16 : 6)
            .scaleEffect(player.isPlaying ? 1 : 0.73)
            .animation(.spring(duration: 0.6, bounce: 0.3), value: player.isPlaying)
    }

    @ViewBuilder
    func InfoRow(scale: CGFloat) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2 * scale) {
                Text(verbatim: currentSong?.title ?? "")
                    .font(.system(size: 21 * scale, weight: .semibold))
                Text(verbatim: subtitle)
                    .font(.system(size: 18 * scale))
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)

            MoreMenu(size: 32 * scale)
        }
    }

    private var subtitle: String {
        guard let currentSong else { return "" }
        return [currentSong.artist.name, currentSong.album.title]
            .filter { !$0.isEmpty }
            .joined(separator: " — ")
    }

    @ViewBuilder
    func MoreMenu(size: CGFloat) -> some View {
        Menu {
            if let currentSong {
                ShareLink(item: currentSong.fileURL,
                          message: Text(verbatim: currentSong.title)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                #if os(macOS)
                Button("Reveal in Finder", systemImage: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([currentSong.fileURL])
                }
                #endif
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: size * 0.45, weight: .bold))
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .glassBackground(in: Circle())
        .disabled(currentSong == nil)
        .help("More")
        .accessibilityLabel("More")
    }
}

// MARK: Controls

extension MusicPlayer {

    @ViewBuilder
    func TransportControls(scale: CGFloat) -> some View {
        HStack(spacing: 0) {
            ModeButton(systemImage: "shuffle", isOn: player.shuffled, help: "Shuffle",
                       scale: scale, action: player.toggleShuffle)
                .accessibilityAddTraits(player.shuffled ? .isSelected : [])

            Spacer(minLength: 0)

            Button(action: player.previousTrack) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 28 * scale))
            }
            .disabled(player.isPlaylistEmpty)
            .accessibilityLabel("Previous")

            Spacer(minLength: 0)

            Button(action: player.togglePlayPause) {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 34 * scale))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 44 * scale, height: 44 * scale)
            }
            .keyboardShortcut(.space, modifiers: [])
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

            Spacer(minLength: 0)

            Button(action: player.nextTrack) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 28 * scale))
            }
            .disabled(player.isPlaylistEmpty)
            .accessibilityLabel("Next")

            Spacer(minLength: 0)

            ModeButton(systemImage: player.playerMode == .repeatItem ? "repeat.1" : "repeat",
                       isOn: player.playerMode != .noRepeat, help: "Repeat",
                       scale: scale, action: player.nextPlayerMode)
                .accessibilityValue(player.playerMode.accessibilityValue)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.primary)
    }

    /// Shuffle and repeat: dimmed while off, lit on a soft circle while on.
    @ViewBuilder
    func ModeButton(systemImage: String, isOn: Bool, help: LocalizedStringKey,
                    scale: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18 * scale, weight: .semibold))
                .foregroundStyle(isOn ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                .frame(width: 36 * scale, height: 36 * scale)
                .background {
                    if isOn { Circle().fill(.primary.opacity(0.18)) }
                }
                .contentShape(Circle())
        }
        .help(help)
        .accessibilityLabel(help)
    }

    @ViewBuilder
    func AccessoryControls() -> some View {
        HStack(spacing: 4) {
            Button {
                lyricsPresented.toggle()
            } label: {
                Image(systemName: "quote.bubble")
                    .symbolVariant(lyricsPresented ? .fill : .none)
                    .frame(width: 36, height: 36)
                    .background {
                        if lyricsPresented { Circle().fill(.primary.opacity(0.2)) }
                    }
                    .contentShape(Circle())
            }
            .help("Lyrics")
            .accessibilityLabel("Lyrics")
            .accessibilityAddTraits(lyricsPresented ? .isSelected : [])

            DevicePickerView(player: player.player)
                .frame(width: 24, height: 24)
                .padding(6)
        }
        .font(.title3)
        .buttonStyle(.borderless)
        .foregroundStyle(.primary)
        .padding(4)
        .glassBackground(in: Capsule())
    }
}

// MARK: Progress

/// The progress bar with the time played, the time left and the audio quality beneath it.
/// Its own view, so the time ticking redraws only this.
fileprivate struct PlaybackProgress: View {

    var isEnabled: Bool
    var quality: AudioQuality?
    var scale: CGFloat

    @Environment(ArthubAudioPlayer.self) private var player
    @State private var scrubTime: TimeInterval? = nil

    var body: some View {
        let time = scrubTime ?? player.currentTime
        VStack(spacing: 6 * scale) {
            PlaybackProgressBar(currentTime: player.currentTime,
                                duration: player.duration,
                                thickness: 6 * scale,
                                onScrub: { scrubTime = $0 },
                                onSeek: player.seek(to:))
                .disabled(!isEnabled)

            HStack {
                Text(verbatim: time.formatted())
                Spacer()
                Text(verbatim: "−" + max(player.duration - time, 0).formatted())
            }
            .overlay {
                if let quality {
                    Label(quality.title, systemImage: "waveform")
                }
            }
            .font(.system(size: 13 * scale, weight: .medium).monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }
}

/// Apple Music's label for lossless audio; lossy formats get none.
fileprivate enum AudioQuality {
    case lossless, hiResLossless

    var title: LocalizedStringKey {
        switch self {
        case .lossless: "Lossless"
        case .hiResLossless: "Hi-Res Lossless"
        }
    }

    init?(url: URL) async {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .audio).first,
              let format = try? await track.load(.formatDescriptions).first?.audioStreamBasicDescription,
              [kAudioFormatFLAC, kAudioFormatAppleLossless, kAudioFormatLinearPCM].contains(format.mFormatID)
        else { return nil }
        // Above 48 kHz is hi-res, as Apple Music counts it.
        self = format.mSampleRate > 48_000 ? .hiResLossless : .lossless
    }
}

// MARK: Volume

/// The volume slider in the toolbar. ↑ and ↓ step it, as before.
fileprivate struct VolumeControl: View {

    @Environment(ArthubAudioPlayer.self) private var player

    private let step: Float = 0.1

    var body: some View {
        @Bindable var player = player
        HStack(spacing: 8) {
            Slider(value: $player.volume, in: 0...1)
                .frame(width: 110)
                .controlSize(.small)
                .accessibilityLabel("Volume")

            Image(systemName: player.volume == 0 ? "speaker.slash.fill" : "speaker.wave.3.fill",
                  variableValue: Double(player.volume))
                .frame(width: 26, alignment: .leading)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 8)
        .background {
            Group {
                Button("") { player.volume = (player.volume + step).clamp(to: 0...1) }
                    .keyboardShortcut(.upArrow, modifiers: [])
                Button("") { player.volume = (player.volume - step).clamp(to: 0...1) }
                    .keyboardShortcut(.downArrow, modifiers: [])
            }
            .opacity(0)
            .accessibilityHidden(true)
        }
        .help("Volume")
    }
}

// MARK: Styling

fileprivate extension View {

    /// Liquid Glass where there is, a material before it.
    @ViewBuilder
    func glassBackground(in shape: some Shape) -> some View {
        if #available(macOS 26.0, iOS 26.0, tvOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}

#Preview {
    NavigationStack {
        MusicPlayer(currentSong: Song(fileURL: URL(filePath: "/"), duration: 300,
                                      lyrics: LyricsDetail(body: Lyric.examples())))
    }
    .environment(ArthubAudioPlayer())
    .environment(WindowState())
    .frame(width: 980, height: 600)
}
