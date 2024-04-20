//
//  VideoPlayer.swift
//  shelf
//
//  Created by 张鸿燊 on 1/2/2024.
//

import SwiftUI
import AVKit
import CoreImage

#if canImport(AppKit)
class PlayerView: NSView {
    
    var player: AVPlayer? {
        get { return playerLayer.player }
        set { playerLayer.player = newValue }
    }
    
    private let playerLayer = AVPlayerLayer()
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        setupPlayerLayer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPlayerLayer()
    }
    
    private func setupPlayerLayer() {
        playerLayer.videoGravity = .resizeAspectFill
        layer = playerLayer
    }

    
    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }
    
}


struct VideoPlayer: NSViewRepresentable {
    
    var player: AVPlayer?
    
    func makeNSView(context: Context) -> NSView {
        let view = PlayerView()
        view.player = player
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Update the view if needed
    }
}


#elseif canImport(UIKit)
struct VideoPlayer: UIViewControllerRepresentable {
    var player: AVPlayer?
    
    func makeUIViewController(context: Context) -> UIViewController {
        let view = AVPlayerViewController()
        view.player = player
        view.allowsPictureInPicturePlayback = true
        return view
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Update the view if needed
    }
}
#endif
