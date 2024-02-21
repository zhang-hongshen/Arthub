//
//  AVAudioPlayerNode+.swift
//  Arthub
//
//  Created by 张鸿燊 on 8/2/2024.
//
import AVFoundation

extension AVAudioPlayerNode  {
    
    var playerTime: AVAudioTime? {
        guard let nodeTime = self.lastRenderTime,
              let playerTime = self.playerTime(forNodeTime: nodeTime) else  {
            return nil
        }
        return playerTime
    }
    
    var currentTime: TimeInterval {
        guard let playerTime = self.playerTime else {
            return 0
        }
        return Double(playerTime.sampleTime) / Double(playerTime.sampleRate)
    }
}
