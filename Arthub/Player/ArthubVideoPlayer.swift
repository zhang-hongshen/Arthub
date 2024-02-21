//
//  ArthubVideoPlayer.swift
//  Arthub
//
//  Created by 张鸿燊 on 4/2/2024.
//

import AVFoundation

@Observable
class ArthubVideoPlayer: ObservableObject {
    
    public var player = AVPlayer(playerItem: nil)
    public var currentTime: TimeInterval = 0
    public var duration: TimeInterval = 0
    public var isPlaying: Bool = false
    public var rate: Float = 1 {
        didSet {
            player.rate = rate
        }
    }
    public var ratio: CGFloat = 1
    
    private var asset: AVAsset? {
        guard let currentPlayerItem = currentPlayerItem else {
            return nil
        }
        return currentPlayerItem.asset
    }
    
    var currentPlayerItem: AVPlayerItem? {
        return player.currentItem
    }
    
    func start(url: URL, startTime: TimeInterval = 0) async throws{
        reset()
        let playerItem = AVPlayerItem(url: url)
        self.player.replaceCurrentItem(with: playerItem)
        player.addPeriodicTimeObserver(
            forInterval: .init(value: 1, timescale: 1),
            queue: .main) {  CMTime in
                DispatchQueue.main.async {
                    self.currentTime  = self.player.currentTime().seconds
                }
        }
        
        self.duration = try await playerItem.asset.load(.duration).seconds
        if startTime > 0 && startTime <= duration {
            await player.seek(to: .init(seconds: startTime, preferredTimescale: 1))
        }
        self.isPlaying = true
        let tracks = try await playerItem.asset.loadTracks(withMediaType: .video)
        guard let track = tracks.first else{
            return
        }
        let naturalSize = try await track.load(.naturalSize)
        setRatio(naturalSize.width / naturalSize.height)
    }
    
    
    func replace(url: URL, startTime: TimeInterval = 0) async throws{
        let playerItem = AVPlayerItem(url: url)
        self.player.replaceCurrentItem(with: playerItem)
        self.duration = try await playerItem.asset.load(.duration).seconds
        if startTime > 0 && startTime <= duration {
            await player.seek(to: .init(seconds: startTime, preferredTimescale: 1))
        }
        let tracks = try await playerItem.asset.loadTracks(withMediaType: .video)
        guard let track = tracks.first else{
            return
        }
        let naturalSize = try await track.load(.naturalSize)
        setRatio(naturalSize.width / naturalSize.height)
    }
    
    func reset() {
        player.replaceCurrentItem(with: nil)
        self.isPlaying = false
        self.currentTime = 0
        self.duration = 0
        self.rate = 1
    }
    
    func isDurationValid() -> Bool {
        return !duration.isZero && !duration.isNaN
    }
    
    func stop() {
        player.stop()
        isPlaying = false
    }
    
    func play() {
        player.play()
        isPlaying = true
    }
        
    func pause() {
        player.pause()
        isPlaying = false
    }
    
    func seek(to time: TimeInterval) {
        player.seek(to: .init(seconds: time, preferredTimescale: 1))
    }
    
    func setVolume(_ volume: Float) {
        player.volume = volume.clamp(to: 0...1)
    }
    
    func setRatio(_ ratio: CGFloat) {
        if ratio > 0 {
            self.ratio = ratio
        }
    }
    
    func generateImage(for time: TimeInterval,
                       completionHanlder: @escaping (CGImage) -> Void) {
        guard let asset = asset else {
            return
        }
        AVAssetImageGenerator(asset: asset)
            .generateCGImageAsynchronously(for:
                    .init(seconds: time,
                          preferredTimescale: 1)) { image, time, err in
                if let err = err {
                    print("generate preview Image error, \(err)")
                    return
                }
                guard let image = image else {
                    print("no image")
                    return
                }
                completionHanlder(image)
                print("generate image success")
        }
    }
}
