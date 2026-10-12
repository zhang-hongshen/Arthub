//
//  DynamicLyricView.swift
//  Arthub
//
//  Created by 张鸿燊 on 23/2/2024.
//

import SwiftUI

struct DynamicLyricView: View {
    
    var lyric: Lyric
    var time: TimeInterval

    @State private var isHovering = false
    
    private var shown: Bool {
        lyric.isActive(at: time)
    }
    
    var body: some View {
        
        Group {
            if shown, let karaoke = lyric.karaokeText(at: time, sung: Color.accent, unsung: .secondary) {
                karaoke
            } else {
                DynamicTextView(text: lyric.content, progress: shown ? 1 : 0)
                    .animation(shown ? .spring(duration: lyric.end - time) : .none, value: shown)
            }
        }
        #if !os(tvOS)
        .onHover(perform: { isHovering = $0 })
        #endif
        .padding()
        .background(isHovering ? .gray.opacity(0.3) : .clear)
        .fixedSize(horizontal: false, vertical: true)
        .multilineTextAlignment(.leading)
        
    }
    
//    func calculateTimeDifference(_ lyrics: [Lyric]) -> [TimeInterval] {
//        guard let first = lyrics.first else { return [] }
//        var timeDifferences: [TimeInterval] = []
//        var previousStartTime: TimeInterval = first.start
//        
//        for lyric in lyrics {
//            let timeDifference = lyric.start - previousStartTime
//            timeDifferences.append(timeDifference)
//            previousStartTime = lyric.start
//        }
//        
//        return timeDifferences
//    }
}

fileprivate struct DynamicTextView: View {
    
    var text: String
    var progress: CGFloat
    
    var body: some View {
        Text(verbatim: text)
            .foregroundStyle(
                .linearGradient(
                    stops: [
                        .init(color: .accent, location: progress),
                        .init(color: .secondary, location: progress),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing)
            )
    }
}

extension DynamicTextView : Animatable {
    
    var animatableData: CGFloat.AnimatableData {
        get { progress.animatableData }
        set { progress.animatableData = newValue }
    }
}

extension Lyric {

    /// The line lit word by word as it is sung, each word across its own duration;
    /// nil without word timing that matches the line.
    func karaokeText(at time: TimeInterval, sung: some ShapeStyle, unsung: some ShapeStyle) -> Text? {
        guard let segments else { return nil }
        var text = Text(verbatim: "")
        var previousEnd = start
        for segment in segments {
            var lit = 0
            if let phrase = segment.phrase {
                let progress = phrase.duration > 0 ? (time - phrase.start) / phrase.duration : (time < phrase.start ? 0 : 1)
                lit = Int((Double(segment.text.count) * min(max(progress, 0), 1)).rounded(.up))
                previousEnd = phrase.end
            } else if time >= previousEnd {
                // Spaces and punctuation light up once the word before them is sung.
                lit = segment.text.count
            }
            text = text + Text(verbatim: String(segment.text.prefix(lit))).foregroundStyle(sung)
                + Text(verbatim: String(segment.text.dropFirst(lit))).foregroundStyle(unsung)
        }
        return text
    }
}
