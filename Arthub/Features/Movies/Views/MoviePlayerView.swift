//
//  MoviePlayerView.swift
//  Arthub
//
//  Created by 张鸿燊 on 1/2/2024.
//

import SwiftUI

struct MoviePlayerView: View {
    
    @Bindable var metrics: UserMetrics
    
    var body: some View {
        VideoPlayerView(currentTime: $metrics.currentTime)
    }
}
