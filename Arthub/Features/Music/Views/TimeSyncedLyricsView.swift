//
//  LyricsView.swift
//  Arthub
//
//  Created by 张鸿燊 on 2/2/2024.
//

import SwiftUI
import AVFoundation

struct TimeSyncedLyricsView: View {
    
    var lyrics: [Lyric]
    var syncedTime: TimeInterval
    var onLyricClicked: (Lyric) -> Void = {_ in}
    
    /// Lyrics without timing (plain embedded text) aren't blurred.
    private var isTimeSynced: Bool { lyrics.contains { $0.end > 0 } }

    /// The first line being sung; lines sharing its time, like a translation, are lit with it.
    private var currentLyricID: Lyric.ID? {
        lyrics.first { $0.isActive(at: syncedTime) }?.id
    }

    var body: some View {
        MainView()
            .overlay {
                if lyrics.isEmpty {
                    ContentUnavailableView("No Lyrics",
                                           systemImage: "chart.bar.doc.horizontal",
                                           description: Text("Please add lyrics!"))
                }
            }
            .padding()
    }
}

extension TimeSyncedLyricsView {
    
    @ViewBuilder
    func MainView() -> some View {
        ScrollView {
            LazyVStack(alignment: .leading) {
                ForEach(lyrics) { lyric in
                    DynamicLyricView(lyric: lyric, time: syncedTime).id(lyric.id)
                        .blur(radius: !isTimeSynced || lyric.isActive(at: syncedTime) ? 0 : 2)
                        .cornerRadius()
                        .onTapGesture { onLyricClicked(lyric) }
                }
                
            }
            .padding()
            .font(.largeTitle.bold())
            .scrollTargetLayout()
        }
        .scrollIndicators(.never)
        .scrollPosition(id: Binding(get: { currentLyricID }, set: { _ in}),
                        anchor: UnitPoint(x: 0.5, y: 0.25))
        .animation(.bouncy(duration: 1), value: currentLyricID)
    }
}
