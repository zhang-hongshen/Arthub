//
//  MoviePlayer.swift
//  shelf
//
//  Created by 张鸿燊 on 1/2/2024.
//

import SwiftUI
import AVKit

struct VideoPlayer: NSViewRepresentable {
    @State var player: AVPlayer
    
    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        return view
    }
    
    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        // Update the view if needed
    }
}

