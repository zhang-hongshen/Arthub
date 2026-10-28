//
//  FileItem.swift
//  Arthub
//
//  Created by 张鸿燊 on 21/3/2024.
//

import Foundation
import AVFoundation

/// One file of a movie or episode that comes in several versions, e.g. `4K` and `1080p`.
struct MediaVersion: Hashable {
    var fileURL: URL
    /// From the file name, e.g. `Director's Cut`.
    var name: String?
    /// The picture width, from the file name until `loadingWidths()` reads the file.
    var width: Int?

    /// What the version picker shows: the name, else `4K` or `1080p` from the width.
    var label: String {
        let resolution: String? = switch width {
        case .none: nil
        case .some(3800...): "4K"
        case .some(2500...): "1440p"
        case .some(1900...): "1080p"
        case .some(1260...): "720p"
        case .some: "SD"
        }
        return name ?? resolution ?? fileURL.fileName
    }

    /// Wider pictures first, then by path so the order is stable.
    func ranksAbove(_ other: MediaVersion) -> Bool {
        (width ?? 0, other.fileURL.path) > (other.width ?? 0, fileURL.path)
    }
}

extension [MediaVersion] {
    /// Reads each file's picture width, widest first.
    /// Files AVFoundation cannot open, such as MKV, keep the width from their name.
    func loadingWidths() async -> [MediaVersion] {
        var versions = self
        for index in versions.indices {
            let asset = AVURLAsset(url: versions[index].fileURL)
            if let track = try? await asset.loadTracks(withMediaType: .video).first,
               let (size, transform) = try? await track.load(.naturalSize, .preferredTransform) {
                versions[index].width = Int(abs(size.applying(transform).width))
            }
        }
        return versions.sorted { $0.ranksAbove($1) }
    }
}

@Observable
class MediaItem {
    var isAvailable = true
    /// The version played by default.
    var fileURL: URL
    var duration: TimeInterval
    /// Every available file of this item, best first; more than one when there is a choice.
    var versions: [MediaVersion] = []
    
    init(fileURL: URL, duration: TimeInterval) {
        self.fileURL = fileURL
        self.duration = duration
    }
}
