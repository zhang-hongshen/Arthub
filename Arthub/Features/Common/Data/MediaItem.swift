//
//  FileItem.swift
//  Arthub
//
//  Created by 张鸿燊 on 21/3/2024.
//

import Foundation

@Observable
class MediaItem {
    var fileURL: URL
    var duration: TimeInterval
    
    init(fileURL: URL, duration: TimeInterval) {
        self.fileURL = fileURL
        self.duration = duration
    }
}
