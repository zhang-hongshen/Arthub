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

    /// Fast, allocation-free checks for common media extensions.
    /// Falls back to UTType conformance for anything else.
    private var isVideoByExtension: Bool {
        if ["mp4", "mov", "avi", "mkv", "m4v", "mpg", "mpeg", "webm", "wmv", "flv", "3gp"]
            .contains(where: { pathExtension.lowercased() == $0 }) {
                return true
        }
        return UTType(filenameExtension: pathExtension)?.conforms(to: .movie) ?? false
    }

    private var isAudioByExtension: Bool {
        if ["mp3", "wav", "aac", "flac", "m4a", "aiff", "aif", "alac", "ogg", "wma", "opus"]
            .contains(where: { pathExtension.lowercased() == $0 }) {
                return true
        }
        return UTType(filenameExtension: pathExtension)?.conforms(to: .audio) ?? false
    }

    var isVideo: Bool {
        isVideoByExtension
    }

    var isAudio: Bool {
        isAudioByExtension || isVideoByExtension
    }

    /// Thorough check that probes the file's actual tracks.
    /// Use for files with unusual extensions; `isVideo`/`isAudio` above
    /// are instant and sufficient for normal libraries.
    func hasVideoTracks() async -> Bool {
        if isVideoByExtension { return true }
        let asset = AVURLAsset(url: self)
        let tracks = (try? await asset.loadTracks(withMediaType: .video)) ?? []
        return !tracks.isEmpty
    }

    func hasAudioTracks() async -> Bool {
        if isAudioByExtension || isVideoByExtension { return true }
        let asset = AVURLAsset(url: self)
        let tracks = (try? await asset.loadTracks(withMediaType: .audio)) ?? []
        return !tracks.isEmpty
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
