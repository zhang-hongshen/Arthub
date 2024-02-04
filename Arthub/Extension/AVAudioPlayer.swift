//
//  AVAudioPlayer.swift
//  Arthub
//
//  Created by 张鸿燊 on 4/2/2024.
//

import Foundation
import AVKit

extension AVAudioPlayer {
    func seek(time: TimeInterval) {
        self.currentTime = time
    }
}
