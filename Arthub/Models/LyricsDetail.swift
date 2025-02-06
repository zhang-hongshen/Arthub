//
//  LyricsDetail.swift
//  Arthub
//
//  Created by 张鸿燊 on 2/3/2024.
//

import Foundation

@Observable
class LyricsDetail: Identifiable, Equatable {
    
    let id = UUID()
    var fileURL: URL?
    var body: [Lyric]
    
    init(fileURL: URL? = nil, body: [Lyric] = []) {
        self.fileURL = fileURL
        self.body = body
    }
    
    static func == (lhs: LyricsDetail, rhs: LyricsDetail) -> Bool {
        return lhs.id == rhs.id
    }
}
