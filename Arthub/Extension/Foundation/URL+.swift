//
//  URL+.swift
//  Arthub
//
//  Created by 张鸿燊 on 15/2/2024.
//

import Foundation
import UniformTypeIdentifiers
import AVFoundation

extension URL {
    
    var isImage: Bool {
        UTType(filenameExtension: pathExtension)?.conforms(to: .image) ?? false
    }
    
    var isVideo: Bool {
        let asset = AVURLAsset(url: self)
        let semaphore = DispatchSemaphore(value: 0)
        var res = false
        asset.loadTracks(withMediaType: .video) { tracks, err in
            if let tracks = tracks {
                res = !tracks.isEmpty
            }
            DispatchQueue.userInitiated.async {
                semaphore.signal()
            }
        }
        semaphore.wait()
        return res
    }
    
    var isAudio: Bool {
        let asset = AVURLAsset(url: self)
        let semaphore = DispatchSemaphore(value: 0)
        var res = false
        asset.loadTracks(withMediaType: .audio) { tracks, err in
            if let tracks = tracks {
                res = !tracks.isEmpty
            }
            DispatchQueue.userInitiated.async {
                semaphore.signal()
            }
        }
        semaphore.wait()
        return res
    }
    
    var fileName: String {
        return self.deletingPathExtension().lastPathComponent.trimmingCharacters(in: .whitespaces)
    }
    
    var isTTML: Bool {
        UTType(filenameExtension: pathExtension)?.conforms(to: .ttml) ?? false
    }
}
