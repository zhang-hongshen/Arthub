//
//  AVPlayerItem+.swift
//  Arthub
//
//  Created by 张鸿燊 on 3/3/2024.
//

import AVFoundation

extension AVPlayerItem {
    
    var url: URL? {
        (asset as? AVURLAsset)?.url
    }
}
