//
//  AlbumDetail.swift
//  Arthub
//
//  Created by 张鸿燊 on 4/2/2024.
//

import Foundation

@Observable
class Album: Identifiable, Hashable {
    let id = UUID()
    let createdAt: Date = Date.now
    var modifiedAt: Date = Date.now
    
    var title: String
    var artist: Artist
    var releaseDate: Date?
    var cover: Data?
    var songs: [Song] = []
    
    init(title: String = "", artist: Artist = Artist(),
         releaseDate: Date? = nil, cover: Data? = nil) {
        self.title = title
        self.artist = artist
        self.releaseDate = releaseDate
        self.cover = cover
    }
    
    static func == (lhs: Album, rhs: Album) -> Bool {
        return lhs.title == rhs.title
        && lhs.artist == rhs.artist
        && lhs.releaseDate == rhs.releaseDate
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(artist)
        hasher.combine(releaseDate)
    }
}
