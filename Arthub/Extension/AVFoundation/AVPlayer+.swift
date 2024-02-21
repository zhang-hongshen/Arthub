//
//  AVPlayer+.swift
//  Arthub
//
//  Created by 张鸿燊 on 18/2/2024.
//

import SwiftUI
import AVFoundation

extension AVPlayer {
    func stop(){
        self.seek(to: CMTime.zero)
        self.pause()
        self.replaceCurrentItem(with: nil)
        self.rate = 0
   }
}

