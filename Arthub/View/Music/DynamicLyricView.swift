//
//  DynamicLyricView.swift
//  Arthub
//
//  Created by 张鸿燊 on 23/2/2024.
//

import SwiftUI

struct DynamicLyricView: View {
    
    @State var lyric: Lyric
    @Binding var syncedTime: TimeInterval
    private var shown: Bool {
        lyric.start <= syncedTime && syncedTime < lyric.end
    }
    
    var body: some View {
        HStack(alignment: .center){
            if lyric.phrases.isEmpty {
                let duration = lyric.end - lyric.start
                DynamicTextView(text: $lyric.content, progress: shown ? 1 : 0)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(.spring(duration: duration), value: shown)
            } else {
                ForEach(lyric.phrases) { lyric in
                    DynamicLyricView(lyric: lyric, syncedTime: $syncedTime)
                }
            }
        }
    }
}

struct DynamicTextView: View {
    
    @Binding var text: String
    var progress: CGFloat
    
    var body: some View {
        Text(verbatim: text)
            .foregroundStyle(
                .linearGradient(
                    stops: [
                        .init(color: Color.gray, location: progress),
                        .init(color: Color.gray.opacity(0.4), location: progress),
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
