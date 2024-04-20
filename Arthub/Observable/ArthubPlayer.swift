//
//  ArthubPlayer.swift
//  Arthub
//
//  Created by 张鸿燊 on 12/3/2024.
//

import Foundation
import AVFoundation

@Observable class ArthubPlayer {
    
    // The player actually being used for playback.
    
    var player: AVPlayer = AVPlayer(playerItem: nil)
    
    var playerMode: PlayerMode { playerModes[playerModeIndex] }
    
    var isPlaying: Bool { playerState == .playing }
    
    var rate: Float { player.rate }
    
    var volume: Float = 0.5 {
        didSet {
            self.player.volume = volume.clamp(to: 0...1)
        }
    }
    
    // Possible values of the `playerState` property.
    
    enum PlayerState {
        case stopped
        case playing
        case paused
    }
    
    // Possible values of the `playerMode` property.
    
    enum PlayerMode {
        case noRepeat
        case repeatPlaylist
        case repeatItem
        
        var systemImageName: String {
            switch self {
            case .noRepeat:
                "repeat.circle"
            case .repeatPlaylist:
                "repeat.circle.fill"
            case .repeatItem:
                "repeat.1.circle.fill"
            }
        }
        
    }
    
    

    var playerState: PlayerState = .stopped
    
    private let playerModes: [PlayerMode] = [.noRepeat, .repeatPlaylist, .repeatItem]
    
    private var playerModeIndex = 0
    
    func nextPlayerMode() {
        playerModeIndex = (playerModeIndex + 1) % playerModes.count
    }
    
    func setPlaybackRate(_ rate: Float) {
        
        if case .stopped = playerState { return }
        
        player.rate = rate
    }
}
