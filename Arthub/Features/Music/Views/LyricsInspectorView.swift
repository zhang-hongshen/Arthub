//
//  LyricsInspectorView.swift
//  Arthub
//
//  Created by 张鸿燊 on 3/10/2026.
//

import SwiftUI
import CoreImage

/// Apple Music style lyrics column: large bold lines, the active line lit,
/// the rest dimmed and blurred, auto-scrolling with playback. Tap a line to seek.
struct LyricsInspectorView: View {

    enum Style {
        case inspector
        /// The full-screen player's larger lines, kept near the middle, over its own background.
        case player(fontSize: CGFloat)
    }

    var song: Song?
    var style: Style = .inspector

    @Environment(ArthubAudioPlayer.self) private var player
    @State private var backgroundColor: Color = .clear
    @State private var isHovering = false
    /// How far this song's lines have been moved, shown while adjusting them.
    @State private var timingShift: TimeInterval = 0
    @State private var timingSave: Task<Void, Never>?

    private var lyrics: [Lyric] { song?.lyrics.body ?? [] }

    /// Lyrics without timing (plain embedded text) are shown statically.
    private var isTimeSynced: Bool { lyrics.contains { $0.end > 0 } }

    /// The first line being sung; lines sharing its time, like a translation, are lit with it.
    private var currentLyricID: Lyric.ID? {
        let time = player.currentTime
        return lyrics.first { $0.isActive(at: time) }?.id
    }

    private var isInspector: Bool {
        switch style {
        case .inspector: true
        case .player: false
        }
    }

    private var fontSize: CGFloat {
        switch style {
        case .inspector: 26
        case .player(let fontSize): fontSize
        }
    }

    var body: some View {
        Group {
            if lyrics.isEmpty {
                NoLyricsView()
            } else if isTimeSynced {
                SyncedLyricsView()
                    .overlay(alignment: .bottomTrailing) {
                        if let song { TimingControl(song) }
                    }
            } else {
                PlainLyricsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            if isInspector { Rectangle().fill(backgroundColor.gradient.opacity(0.35)) }
        }
        .task(id: song?.id) {
            timingShift = 0
            if isInspector { updateBackgroundColor() }
        }
        #if os(macOS)
        .onHover { isHovering = $0 }
        #endif
    }
}

extension LyricsInspectorView {

    @ViewBuilder
    func SyncedLyricsView() -> some View {
        // The player's intro dots and first line start where the line being sung stays.
        let anchor: CGFloat = isInspector ? 0.3 : 0.4
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: isInspector ? 8 : fontSize * 0.8) {
                        if let first = lyrics.first, first.start > 3, player.currentTime < first.start {
                            InterludeDots(progress: player.currentTime / first.start,
                                          size: isInspector ? 12 : fontSize * 0.7)
                                .padding(.horizontal, 12)
                        }
                        ForEach(lyrics) { lyric in
                            LyricLine(lyric: lyric,
                                      isActive: lyric.isActive(at: player.currentTime),
                                      isPast: lyric.end <= player.currentTime,
                                      blurred: !isHovering,
                                      fontSize: fontSize,
                                      blurRadius: isInspector ? 1.2 : fontSize * 0.12)
                                .id(lyric.id)
                                .onTapGesture { player.seek(to: lyric.start) }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, isInspector ? 60 : geometry.size.height * anchor)
                    .padding(.bottom, isInspector ? 60 : geometry.size.height * (1 - anchor))
                }
                .scrollIndicators(.never)
                .onChange(of: currentLyricID, initial: true) { _, id in
                    guard let id else { return }
                    withAnimation(.smooth(duration: 0.6)) {
                        proxy.scrollTo(id, anchor: UnitPoint(x: 0, y: anchor))
                    }
                }
            }
        }
        .mask {
            // The player's lines fade out at the top and bottom instead of being cut off.
            let edge = Color.black.opacity(isInspector ? 1 : 0)
            LinearGradient(stops: [.init(color: edge, location: 0), .init(color: .black, location: 0.12),
                                   .init(color: .black, location: 0.88), .init(color: edge, location: 1)],
                           startPoint: .top, endPoint: .bottom)
        }
    }

    @ViewBuilder
    func NoLyricsView() -> some View {
        if song?.lyrics.lookup == .searching {
            ProgressView("Searching for Lyrics…")
        } else {
            ContentUnavailableView("No Lyrics", systemImage: "quote.bubble", description: Text(noLyricsDescription))
        }
    }

    private var noLyricsDescription: LocalizedStringKey {
        guard let song else { return "Nothing is playing." }
        return switch song.lyrics.lookup {
        case .notFound: "No lyrics were found online."
        case .failed: "Couldn't search for lyrics. Check your connection and try again."
        default: "This song has no lyrics."
        }
    }

    /// Shown on hover: moves the lines for a recording whose singing comes sooner or later than
    /// the lyrics were timed for, such as a music video's.
    @ViewBuilder
    func TimingControl(_ song: Song) -> some View {
        let step: TimeInterval = 0.5
        HStack(spacing: 4) {
            Button("Earlier", systemImage: "minus") { adjustTiming(song, by: -step) }
                .help("Shows the lyrics 0.5 seconds earlier.")
            Text(Measurement(value: timingShift, unit: UnitDuration.seconds),
                 format: .measurement(width: .narrow, usage: .asProvided,
                                      numberFormatStyle: FloatingPointFormatStyle<Double>()
                                        .precision(.fractionLength(1)).sign(strategy: .always())))
                .monospacedDigit()
                .help("How far the lyrics have been moved.")
            Button("Later", systemImage: "plus") { adjustTiming(song, by: step) }
                .help("Shows the lyrics 0.5 seconds later.")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .font(.callout)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .padding(12)
        .opacity(isHovering ? 1 : 0)
        .allowsHitTesting(isHovering)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
    }

    /// Saved into the song once the adjusting stops, rather than the file rewritten for every step.
    private func adjustTiming(_ song: Song, by offset: TimeInterval) {
        song.lyrics.shift(by: offset)
        timingShift += offset
        timingSave?.cancel()
        timingSave = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            try? await song.saveLyrics()
        }
    }

    @ViewBuilder
    func PlainLyricsView() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: isInspector ? 12 : fontSize * 0.5) {
                ForEach(lyrics) { lyric in
                    Text(verbatim: lyric.content)
                }
            }
            .font(isInspector ? Font.title3.weight(.semibold) : .system(size: fontSize, weight: .bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .textSelection(.enabled)
        }
        .scrollIndicators(.never)
    }

    private func updateBackgroundColor() {
        if let cover = song?.album.cover,
           let image = CIImage(data: cover),
           let color = image.averageColor {
            backgroundColor = Color(cgColor: color)
        } else {
            backgroundColor = .clear
        }
    }
}

fileprivate struct LyricLine: View {

    var lyric: Lyric
    var isActive: Bool
    var isPast: Bool
    var blurred: Bool
    var fontSize: CGFloat = 26
    var blurRadius: CGFloat = 1.2

    @Environment(ArthubAudioPlayer.self) private var player
    @State private var isHovering = false

    var body: some View {
        Group {
            if isActive, lyric.segments != nil {
                // Words follow the exact position; `currentTime` only ticks every 0.25 s.
                TimelineView(.animation(minimumInterval: 1 / 30, paused: !player.isPlaying)) { _ in
                    lyric.karaokeText(at: player.playbackTime, sung: .primary, unsung: .secondary)
                        ?? Text(verbatim: lyric.content)
                }
            } else {
                Text(verbatim: lyric.content)
            }
        }
        .font(.system(size: fontSize, weight: .bold))
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(isActive ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary.opacity(isPast ? 0.55 : 0.4)))
        .blur(radius: isActive || !blurred ? 0 : blurRadius)
        .scaleEffect(isActive ? 1 : 0.97, anchor: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            if isHovering { RoundedRectangle(cornerRadius: 10).fill(.primary.opacity(0.08)) }
        }
        .contentShape(Rectangle())
        #if os(macOS)
        .onHover { isHovering = $0 }
        #endif
        .animation(.smooth(duration: 0.4), value: isActive)
    }
}

/// Breathing dots shown during an instrumental intro, lit one by one as it plays, as in Apple Music.
fileprivate struct InterludeDots: View {

    /// How far through the intro playback is.
    var progress: Double
    var size: CGFloat = 12

    @State private var breathing = false

    var body: some View {
        HStack(spacing: size * 0.6) {
            ForEach(0..<3) { index in
                Circle()
                    .frame(width: size, height: size)
                    .opacity(0.25 + 0.75 * (progress * 3 - Double(index)).clamp(to: 0...1))
            }
        }
        .animation(.linear(duration: 0.25), value: progress)
        .foregroundStyle(.primary)
        .scaleEffect(breathing ? 1.08 : 0.94, anchor: .leading)
        .animation(.easeInOut(duration: 1.6).repeatForever(), value: breathing)
        .padding(.vertical, size)
        .onAppear { breathing = true }
    }
}

#Preview {
    LyricsInspectorView(song: Song(fileURL: URL(filePath: "/"), duration: 300,
                                   lyrics: LyricsDetail(body: Lyric.examples())))
        .environment(ArthubAudioPlayer())
        .frame(width: 320, height: 600)
}
