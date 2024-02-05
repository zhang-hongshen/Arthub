//
//  AVPlayer.swift
//  Arthub
//
//  Created by 张鸿燊 on 4/2/2024.
//

import Foundation
import AVKit

class ArthubPlayer: ObservableObject {
    @Published var videoPlayer: AVPlayer? = nil
    @Published var audioPlayer: AVAudioPlayer? = nil
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    
    @MainActor
    func setVideoPlayer(url: URL, startTime: TimeInterval = 0) async throws{
        reset()
        self.videoPlayer = AVPlayer(url: url)
        guard let player = videoPlayer else  {
            return
        }
        guard let currentPlayerItem = player.currentItem else {
            return
        }
        self.duration = try await currentPlayerItem.asset.load(.duration).seconds
        debugPrint("self.duration  = \(duration.description)")
        player.addPeriodicTimeObserver(
            forInterval: .init(value: 1, timescale: 1),
            queue: .main) {  CMTime in
                self.currentTime  = player.currentTime().seconds
        }
        if startTime > 0 && startTime <= duration {
            await player.seek(to: .init(seconds: startTime, preferredTimescale: 1))
        }
    }
    
    @MainActor
    func setAudioPlayer(url: URL) async throws{
        reset()
        self.audioPlayer = try AVAudioPlayer(contentsOf: url)
        guard let player = audioPlayer else  {
            return
        }
        while(!player.prepareToPlay()){}
        self.duration = player.duration
    }
    
    @MainActor
    func reset() {
//        if let videoPlayer = videoPlayer {
//            videoPlayer.pause()
//        }
//        if let audioPlayer = audioPlayer {
//            audioPlayer.pause()
//        }
        self.videoPlayer = nil
        self.audioPlayer = nil
        self.currentTime = 0
        self.duration = 0
    }
    
    func durationValid() -> Bool {
        return !duration.isZero && !duration.isNaN
    }
}
