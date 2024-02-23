//
//  LyricsView.swift
//  Arthub
//
//  Created by 张鸿燊 on 2/2/2024.
//

import SwiftUI
import AVFoundation

struct TimeSyncedLyricsView: View {
    
    @Binding var lyrics: [Lyric]
    @Binding var syncedTime: TimeInterval
    @State var onLyricClicked: (Lyric) -> Void = {_ in}
    
    @State private var hoveringLyricID : Lyric.ID? = nil
    
    private var currentLyricID: Lyric.ID? {
        lyrics.first { $0.start <= syncedTime && $0.end > syncedTime }?.id
    }

    var body: some View {
        if lyrics.isEmpty {
            NoLyricsView()
        } else {
            MainView()
        }
    }
}

extension TimeSyncedLyricsView {
    
    @ViewBuilder
    func NoLyricsView() -> some View {
        Text("No Lyrics Available")
            .font(.largeTitle)
            .fontWeight(.bold)
    }
    
    @ViewBuilder
    func MainView() -> some View {
        ScrollView {
            LazyVStack(alignment: .leading) {
                ForEach(lyrics.sorted(using: KeyPathComparator(\Lyric.start, order: .forward))) { lyric in
                    DynamicLyricView(lyric: lyric, syncedTime: $syncedTime).id(lyric.id)
                        .padding(10)
                        .background {
                            RoundedRectangle(cornerRadius: .defaultCornerRadius)
                                .opacity(hoveringLyricID == lyric.id ? 0.2 : 0)
                        }
                        .blur(radius: currentLyricID == lyric.id ? 0 : 2)
                        .onTapGesture { onLyricClicked(lyric) }
                        .onHover { hovering in
                            hoveringLyricID = hovering ? lyric.id : nil
                        }
                }
            }
            .font(.largeTitle)
            .fontWeight(.bold)
            .scrollTargetLayout()
        }
        .scrollIndicators(.never)
        .scrollPosition(id: Binding(get: { currentLyricID }, set: { _ in}),
                        anchor: UnitPoint(x: 0.5, y: 0.25))
        .animation(.bouncy(duration: 1), value: currentLyricID)
    }
}


#Preview {
    TimeSyncedLyricsView(lyrics: .constant(Lyric.examples()), syncedTime: .constant(19))
        .frame(width: 500, height: 500)
        .environment(ArthubAudioPlayer(AudioNowPlayableBehavior()))
}
