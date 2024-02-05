//
//  LyricsView.swift
//  Arthub
//
//  Created by 张鸿燊 on 2/2/2024.
//

import SwiftUI
import AVKit
struct TimeSyncedLyricsView: View {
    
    @State var lyrics: [LyricSegment] = LyricSegment.examples()
    @Binding var currentTime: TimeInterval
    @State var onLyricClicked : (LyricSegment) -> Void = { _ in }

    
    @State private var currentLyricID : UUID? = nil
    @State private var hoveringLyricID : UUID? = nil
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(lyrics) { lyric in
                        let shown = lyric.startedAt <= currentTime
                            && lyric.endedAt >= currentTime
                        
                        Button {
                            onLyricClicked(lyric)
                        } label: {
                            Text(lyric.content)
                                .multilineTextAlignment(.leading)
                                .padding(15)
                                .blur(radius: shown ? 0.0 : 1.5)
                        }
                        .buttonStyle(.borderless)
                        .id(lyric.id)
                        .background{
                            RoundedRectangle(cornerRadius: .defaultCornerRadius)
                                .fill(hoveringLyricID == lyric.id ? .highlightColor.opacity(0.4) : Color.clear)
                        }
                        .onHover { hovering in
                            hoveringLyricID = hovering ? lyric.id : nil
                        }
                        .onChange(of: shown, initial: true) {
                            if shown {
                                currentLyricID = lyric.id
                            }
                        }
                    }
                }
                .font(.largeTitle)
                .fontWeight(.bold)
            }
            .scrollIndicators(.never)
            .onChange(of: currentLyricID, initial: true) {
                withAnimation(Animation.smooth()) {
                    proxy.scrollTo(currentLyricID, anchor: .center)
                }
            }
        }
    }
}

#Preview {
    TimeSyncedLyricsView(lyrics: LyricSegment.examples(), currentTime: .constant(10))
        .frame(width: 500, height: 500)
}
