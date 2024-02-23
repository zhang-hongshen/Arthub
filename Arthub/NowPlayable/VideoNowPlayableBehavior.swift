//
//  VideoNowPlayableBehavior.swift
//  Arthub
//
//  Created by 张鸿燊 on 22/2/2024.
//

import Foundation
import MediaPlayer

class VideoNowPlayableBehavior: NowPlayable {
    
    var defaultAllowsExternalPlayback: Bool { return true }
    
    var defaultRegisteredCommands: [NowPlayableCommand] {
        return [.play,
                .pause,
                .togglePausePlay,
                .skipBackward,
                .skipForward,
        ]
    }
    
    var defaultDisabledCommands: [NowPlayableCommand] {
        
        // By default, no commands are disabled.
        
        return [
            .nextTrack,
            .previousTrack,
            .changeShuffleMode,
            .changePlaybackPosition,
            .enableLanguageOption,
            .disableLanguageOption,
            .changePlaybackRate
        ]
    }
    
    func handleNowPlayableConfiguration(commands: [NowPlayableCommand],
                                        disabledCommands: [NowPlayableCommand],
                                        commandHandler: @escaping (NowPlayableCommand, MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus,
                                        interruptionHandler: @escaping (NowPlayableInterruption) -> Void) {
        
        // Use the default behavior for registering commands.
        
        configureRemoteCommands(commands, disabledCommands: disabledCommands, commandHandler: commandHandler)
    }
    
    func handleNowPlayableSessionStart() {
        
        // Set the playback state.
        
        MPNowPlayingInfoCenter.default().playbackState = .paused
    }
    
    func handleNowPlayableSessionEnd() {
        
        // Set the playback state.
        
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }
    
    func handleNowPlayableItemChange(metadata: NowPlayableStaticMetadata) {
        
        // Use the default behavior for setting player item metadata.
        
        setNowPlayingMetadata(metadata)
    }
    
    func handleNowPlayablePlaybackChange(playing isPlaying: Bool, metadata: NowPlayableDynamicMetadata) {
        
        // Start with the default behavior for setting playback information.
        
        setNowPlayingPlaybackInfo(metadata)
        
        // Then set the playback state, too.
        
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused

    }
    
}

