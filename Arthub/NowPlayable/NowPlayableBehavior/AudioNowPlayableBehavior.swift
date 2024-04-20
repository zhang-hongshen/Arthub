//
//  AudioNowPlayableBehavior.swift
//  Arthub
//
//  Created by 张鸿燊 on 15/3/2024.
//

import Foundation

class AudioNowPlayableBehavior: NowPlayableBehavior {
    
    override var defaultRegisteredCommands: [NowPlayableCommand] {
        return [.togglePausePlay,
                .play,
                .pause,
                .nextTrack,
                .previousTrack,
                .changePlaybackPosition,
        ]
    }
    
    override var defaultDisabledCommands: [NowPlayableCommand] {
        
        // By default, no commands are disabled.
        
        return [
            .skipBackward,
            .skipForward,
            .changePlaybackRate,
            .enableLanguageOption,
            .disableLanguageOption
        ]
    }
}
