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

    var song: Song?

    @Environment(ArthubAudioPlayer.self) private var player
    @State private var backgroundColor: Color = .clear
    @State private var isHovering = false

    private var lyrics: [Lyric] { song?.lyrics.body ?? [] }

    /// Lyrics without timing (plain embedded text) are shown statically.
    private var isTimeSynced: Bool { lyrics.contains { $0.end > 0 } }

    private var currentLyricID: Lyric.ID? {
        let time = player.currentTime
        return lyrics.first { $0.start <= time && time < $0.end }?.id
    }

    var body: some View {
        Group {
            if lyrics.isEmpty {
                ContentUnavailableView("No Lyrics",
                                       systemImage: "quote.bubble",
                                       description: Text(song == nil ? "Nothing is playing." : "This song has no lyrics."))
            } else if isTimeSynced {
                SyncedLyricsView()
            } else {
                PlainLyricsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor.gradient.opacity(0.35))
        .task(id: song?.id) { updateBackgroundColor() }
        #if os(macOS)
        .onHover { isHovering = $0 }
        #endif
    }
}

extension LyricsInspectorView {

    @ViewBuilder
    func SyncedLyricsView() -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if let first = lyrics.first, first.start > 3, player.currentTime < first.start {
                        InterludeDots().padding(.horizontal, 12)
                    }
                    ForEach(lyrics) { lyric in
                        LyricLine(lyric: lyric,
                                  isActive: lyric.id == currentLyricID,
                                  isPast: lyric.end <= player.currentTime,
                                  blurred: !isHovering)
                            .id(lyric.id)
                            .onTapGesture { player.seek(to: lyric.start) }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 60)
            }
            .scrollIndicators(.never)
            .onChange(of: currentLyricID, initial: true) { _, id in
                guard let id else { return }
                withAnimation(.smooth(duration: 0.6)) {
                    proxy.scrollTo(id, anchor: UnitPoint(x: 0, y: 0.3))
                }
            }
        }
    }

    @ViewBuilder
    func PlainLyricsView() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(lyrics) { lyric in
                    Text(verbatim: lyric.content)
                }
            }
            .font(.title3.weight(.semibold))
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

    @State private var isHovering = false

    private var content: String {
        lyric.phrases.isEmpty ? lyric.content : lyric.phrases.map(\.content).joined(separator: " ")
    }

    var body: some View {
        Text(verbatim: content)
            .font(.system(size: 26, weight: .bold))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(isActive ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary.opacity(isPast ? 0.55 : 0.4)))
            .blur(radius: isActive || !blurred ? 0 : 1.2)
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

/// Pulsing dots shown during an instrumental intro, as in Apple Music.
fileprivate struct InterludeDots: View {

    @State private var pulse = false

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<3) { index in
                Circle()
                    .frame(width: 12, height: 12)
                    .opacity(pulse ? 0.9 : 0.3)
                    .animation(.easeInOut(duration: 0.8)
                        .repeatForever()
                        .delay(Double(index) * 0.2), value: pulse)
            }
        }
        .foregroundStyle(.secondary)
        .padding(.vertical, 12)
        .onAppear { pulse = true }
    }
}

#Preview {
    LyricsInspectorView(song: Song(fileURL: URL(filePath: "/"), duration: 300,
                                   lyrics: LyricsDetail(body: Lyric.examples())))
        .environment(ArthubAudioPlayer())
        .frame(width: 320, height: 600)
}
