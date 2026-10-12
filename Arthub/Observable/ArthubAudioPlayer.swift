//
//  ArthubAudioPlayer.swift
//  Arthub
//
//  Created by 张鸿燊 on 22/2/2024.
//

import AVFoundation
import MediaPlayer

@Observable
class ArthubAudioPlayer: ArthubPlayer {

    var shuffled = false

    /// The exact position for per-frame UI such as word-timed lyrics; `currentTime` only ticks every 0.25 s.
    var playbackTime: TimeInterval {
        let seconds = player.currentTime().seconds
        return isPlaying && seconds.isFinite ? seconds : currentTime
    }

    init() {
        super.init(mediaType: .audio)
    }

    func toggleShuffle() {
        shuffled.toggle()
    }

    override func nextIndex() -> Int? {
        if shuffled { return items.indices.randomElement() }
        return super.nextIndex()
    }

    override func setUpRemoteCommands() {
        super.setUpRemoteCommands()
        let center = MPRemoteCommandCenter.shared()
        handle(center.nextTrackCommand) { _ in self.nextTrack() }
        handle(center.previousTrackCommand) { _ in self.previousTrack() }
    }
}
