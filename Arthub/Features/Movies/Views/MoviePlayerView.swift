//
//  MoviePlayerView.swift
//  Arthub
//
//  Created by 张鸿燊 on 1/2/2024.
//

import SwiftUI

struct MoviePlayerView: View {
    
    let metrics: UserMetrics

    var body: some View {
        VideoPlayerView(startTime: metrics.currentTime, onProgress: { _, time in
            WatchProgressStore.shared.record(time, for: metrics)
        })
    }
}
