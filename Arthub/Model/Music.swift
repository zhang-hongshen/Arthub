//
//  Music.swift
//  Shelf
//
//  Created by 张鸿燊 on 1/2/2024.
//

import Foundation
import SwiftData
import RegexBuilder

enum Metadata: String {
    case album = "album"
    case album_artist = "album_artist"
    case artist = "artist"
    case lyrics = "lyrics"
    case genre = "genre"
}

@Model
class Music {
    @Attribute(.unique) let id = UUID()
    let createdAt: Date = Date.now
    var modifiedAt: Date = Date.now
    
    var name: String
    var filepath: String
    var thumbnail: String
    
    var artist: String
    
    var releaseYear: String
    
    @Relationship(deleteRule:.cascade, inverse: \LyricSegment.music)
    var lyrics = [LyricSegment]()
    
    // User Metrics
    var count: Int64
    
    var album: Album?
    
    init(name: String = "" , filepath: String = "", thumbnail: String = "",
         artist: String = "", releaseYear: String = "",
         lyrics: [LyricSegment] = [], count: Int64 = 0) {
        self.name = name
        self.filepath = filepath
        self.thumbnail = thumbnail
        self.artist = artist
        self.releaseYear = releaseYear
        self.lyrics =  lyrics
        self.count = count
    }
}

extension Music: Hashable {
    static func == (lhs: Music, rhs: Music) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Music {
    static public func examples() -> [Music] {
        return [
            Music(name: "安静", filepath: "music", thumbnail: "music_1"),
            Music(name: "不能说的秘密", filepath: "music", thumbnail: "music_1"),
            Music(name: "不能说的秘密", filepath: "music", thumbnail: "music_1"),
            Music(name: "不能说的秘密", filepath: "music", thumbnail: "music_1"),
            Music(name: "彩虹", filepath: "music", thumbnail: "music_2"),
            Music(name: "彩虹", filepath: "music", thumbnail: "music_2"),
            Music(name: "彩虹", filepath: "music", thumbnail: "music_2"),
            Music(name: "彩虹", filepath: "music", thumbnail: "music_2"),
        ]
    }
}
