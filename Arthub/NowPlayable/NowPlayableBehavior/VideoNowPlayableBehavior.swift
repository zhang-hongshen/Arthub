//
//  VideoNowPlayableBehavior.swift
//  Arthub
//
//  Created by 张鸿燊 on 15/3/2024.
//

import Foundation

class VideoNowPlayableBehavior: NowPlayableBehavior {
    
    override var defaultRegisteredCommands: [NowPlayableCommand] {
        return [.togglePausePlay,
                .play,
                .pause,
                
                .skipBackward,
                .skipForward,
                .changePlaybackPosition,
                .changePlaybackRate,
                .enableLanguageOption,
                .disableLanguageOption
        ]
    }
    
    override var defaultDisabledCommands: [NowPlayableCommand] {
        
        // By default, no commands are disabled.
        
        return [
            .nextTrack,
            .previousTrack,
        ]
    }
}
