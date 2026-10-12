//
//  URL+.swift
//  Arthub
//
//  Created by 张鸿燊 on 15/2/2024.
//

import Foundation
import UniformTypeIdentifiers

extension URL {

    var isImage: Bool { conforms(to: .image) }

    var isVideo: Bool { conforms(to: .movie) || ["mkv", "webm", "wmv", "flv"].contains(pathExtension.lowercased()) }

    var isAudio: Bool { conforms(to: .audio) || ["ogg", "opus", "wma"].contains(pathExtension.lowercased()) }

    var isTTML: Bool { conforms(to: .ttml) }

    var isLRC: Bool { pathExtension.lowercased() == "lrc" }

    /// The file name without its extension.
    var fileName: String {
        deletingPathExtension().lastPathComponent.trimmingCharacters(in: .whitespaces)
    }

    private func conforms(to type: UTType) -> Bool {
        UTType(filenameExtension: pathExtension)?.conforms(to: type) ?? false
    }
}
