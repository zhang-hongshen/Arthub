//
//  ArthubVideoPlayer.swift
//  Arthub
//
//  Created by 张鸿燊 on 4/2/2024.
//

import AVFoundation
import MediaPlayer

@Observable
class ArthubVideoPlayer: ArthubPlayer {

    init() {
        super.init(mediaType: .video)
    }

    override func setUpRemoteCommands() {
        super.setUpRemoteCommands()
        let center = MPRemoteCommandCenter.shared()
        center.skipForwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.preferredIntervals = [15]
        handle(center.skipForwardCommand) { _ in self.skip(by: 15) }
        handle(center.skipBackwardCommand) { _ in self.skip(by: -15) }
        handle(center.changePlaybackRateCommand) { event in
            if let event = event as? MPChangePlaybackRateCommandEvent { self.playbackRate = event.playbackRate }
        }
    }
}
