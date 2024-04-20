//
//  AlbumDetail.swift
//  Arthub
//
//  Created by 张鸿燊 on 4/2/2024.
//

import Foundation

@Observable
class AlbumDetail: Identifiable, Hashable {
    let id = UUID()
    let createdAt: Date = Date.now
    var modifiedAt: Date = Date.now
    
    var title: String
    var artist: ArtistDetail
    var releaseDate: Date?
    var cover: Data?
    var musics: [MusicDetail] = []
    
    init(title: String = "", artist: ArtistDetail = ArtistDetail(),
         releaseDate: Date? = nil, cover: Data? = nil) {
        self.title = title
        self.artist = artist
        self.releaseDate = releaseDate
        self.cover = cover
    }
    
    static func == (lhs: AlbumDetail, rhs: AlbumDetail) -> Bool {
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
