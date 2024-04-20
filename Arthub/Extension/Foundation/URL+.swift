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
        if ["jpg", "jpeg", "png", "gif", "bmp", "svg"]
            .contains(where: { pathExtension.lowercased() == $0 }) {
                return true
        }
        return UTType(filenameExtension: pathExtension)?.conforms(to: .image) ?? false
    }
    
    var isVideo: Bool {
        if ["mp4", "mov", "avi", "mkv"]
            .contains(where: { pathExtension.lowercased() == $0 }) {
                return true
        }
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
        if ["mp3", "wav", "aac", "flac", "m4a"]
            .contains(where: { pathExtension.lowercased() == $0 }) {
                return true
        }
        if isVideo { return true }
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
        self.deletingPathExtension().lastPathComponent.trimmingCharacters(in: .whitespaces)
    }
    
    var isTTML: Bool {
        UTType(filenameExtension: pathExtension)?.conforms(to: .ttml) ?? false
    }
    
    var parentDirectory: URL? {
        do {
            return try resourceValues(forKeys:[.parentDirectoryURLKey]).parentDirectory
        } catch {
            return nil
        }
    }
    
    func copy(to: URL) throws -> URL? {
        guard self.isFileURL else { return nil }
        let fileManager = FileManager.default
        var res: URL? = nil
        do {
            let tempURL = try fileManager.url(for: .itemReplacementDirectory,
                                        in: .userDomainMask,
                                        appropriateFor: to,
                                        create: true)
                .appending(path: self.fileName, directoryHint: .notDirectory)
                .appendingPathExtension(self.pathExtension)
            try fileManager.copyItem(at: self, to: tempURL)
            res = tempURL
            res = try fileManager.replaceItemAt(to, withItemAt: tempURL,
                                                backupItemName: UUID().uuidString)
        } catch {
            print("\(error)")
        }
        return res
    }
    
    var addedAt: Date? {
        do {
            return try resourceValues(forKeys:[.addedToDirectoryDateKey]).addedToDirectoryDate
        } catch {
            return nil
        }
    }
}
