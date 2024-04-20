//
//  DynamicLyricView.swift
//  Arthub
//
//  Created by 张鸿燊 on 23/2/2024.
//

import SwiftUI

struct DynamicLyricView: View {
    
    var lyric: Lyric
    @Binding var syncedTime: TimeInterval

    @State private var progress: CGFloat = 0
    @State private var isHovering = false
    
    private var shown: Bool {
        lyric.start <= syncedTime && syncedTime < lyric.end
    }
    
    var body: some View {
        
        let content = lyric.phrases.isEmpty ? lyric.content : lyric.phrases.map { $0.content }.joined(separator: " ")
        
        DynamicTextView(text: content, progress: shown ? 1 : 0)
            #if !os(tvOS)
            .onHover(perform: { isHovering = $0 })
            #endif
            .padding()
            .background(isHovering ? .gray.opacity(0.3) : .clear)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
            .animation(shown ? .spring(duration: lyric.duration + lyric.start - syncedTime) : .none,
                       value: shown)
        
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
    
    @State var text: String
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
