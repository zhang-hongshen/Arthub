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
    @Published var currentDuration: TimeInterval = 0
    @Published var totalDuration: TimeInterval = 0
    
    @MainActor
    func setVideoPlayer(url: URL) async throws{
        reset()
        self.videoPlayer = AVPlayer(url: url)
        guard let player = videoPlayer else  {
            return
        }
        guard let curretnPlayerItem = player.currentItem else {
            return
        }

        self.totalDuration = try await curretnPlayerItem.asset.load(.duration).seconds
        player.addPeriodicTimeObserver(
            forInterval: .init(value: 1, timescale: 1),
            queue: .main) {  CMTime in
                self.currentDuration  = player.currentTime().seconds
        }
    }
    
    @MainActor
    func setAudioPlayer(url: URL) async throws{
        reset()
        self.audioPlayer = try AVAudioPlayer(contentsOf: url)
        guard let player = audioPlayer else  {
            return
        }
        self.totalDuration = player.duration
    }
    
    @MainActor
    func reset() {
        if let videoPlayer = videoPlayer {
            videoPlayer.pause()
        }
        if let audioPlayer = audioPlayer {
            audioPlayer.pause()
        }
        self.videoPlayer = nil
        self.audioPlayer = nil
        self.currentDuration = 0
        self.totalDuration = 0
    }
    
    func totalDurationValid() -> Bool {
        return !totalDuration.isZero && !totalDuration.isNaN
    }
}
