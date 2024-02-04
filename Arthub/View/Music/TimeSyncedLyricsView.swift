//
//  LyricsView.swift
//  Arthub
//
//  Created by 张鸿燊 on 2/2/2024.
//

import SwiftUI
import AVKit
struct TimeSyncedLyricsView: View {
    @State var lyrics: String
    @Binding var  currentDuration: TimeInterval
    
    @EnvironmentObject var arthubPlayer: ArthubPlayer
    @State private var lyricSegments: [LyricSegment] = LyricSegment.examples()
    
    @State private var currentLyricIndex : Int? = nil
    @State private var hoveringLyricIndex : Int? = nil
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading) {
                    if let player = arthubPlayer.audioPlayer {
                        ForEach(lyricSegments.indices, id:\.self) { i in
                            let lyric = lyricSegments[i]
                            let shown = (lyric.startedAt != nil) && (lyric.endedAt != nil)
                            && lyric.startedAt! <= currentDuration
                            && lyric.endedAt! >= currentDuration
                            
                            Button {
                                if let startedAt = lyric.startedAt {
                                    player.seek(time: startedAt)
                                }
                            } label: {
                                Text(lyric.text)
                                    .multilineTextAlignment(.leading)
                                    .padding(15)
                                    .blur(radius: shown ? 0.0 : 1.5)
                            }
                            .buttonStyle(.borderless)
                            .id(i)
                            .background{
                                RoundedRectangle(cornerRadius: .defaultCornerRadius)
                                    .fill(hoveringLyricIndex == i ? .highlightColor.opacity(0.4) : Color.clear)
                            }
                            .onHover { hovering in
                                hoveringLyricIndex = hovering ? i : nil
                            }
                            .onChange(of: shown, initial: true) {
                                if shown {
                                    currentLyricIndex = i
                                }
                            }
                        }
                    }
                }
                .font(.largeTitle)
                .fontWeight(.bold)
            }
            .scrollIndicators(.never)
            .onChange(of: currentLyricIndex, initial: true) {
                withAnimation(Animation.smooth()) {
                    proxy.scrollTo(currentLyricIndex, anchor: .center)
                }
            }
        }
    }
}

#Preview {
    TimeSyncedLyricsView(lyrics: "", currentDuration: .constant(10))
        .frame(width: 500, height: 500)
}
