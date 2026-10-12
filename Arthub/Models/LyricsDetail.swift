//
//  LyricsDetail.swift
//  Arthub
//
//  Created by 张鸿燊 on 2/3/2024.
//

import Foundation

@Observable
class LyricsDetail: Identifiable, Equatable {
    
    /// Looking lyrics up online for a song without any.
    enum Lookup {
        case searching, found, notFound, failed
    }

    let id = UUID()
    var fileURL: URL?
    var body: [Lyric]
    /// `body` isn't in `fileURL` yet: changed in the lyrics editor, moved, or found online.
    var isUnsaved = false
    /// Done once a session, unless it failed or is asked for again.
    var lookup: Lookup?
    
    init(fileURL: URL? = nil, body: [Lyric] = []) {
        self.fileURL = fileURL
        self.body = body
    }
    
    /// Moves every line, for lyrics timed to another recording of the song, such as its music video;
    /// a negative offset shows them earlier.
    func shift(by offset: TimeInterval) {
        body.forEach { $0.shift(by: offset) }
        isUnsaved = true
    }

    static func == (lhs: LyricsDetail, rhs: LyricsDetail) -> Bool {
        return lhs.id == rhs.id
    }
}
