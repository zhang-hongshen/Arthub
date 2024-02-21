//
//  Album.swift
//  Arthub
//
//  Created by 张鸿燊 on 4/2/2024.
//

import Foundation

class Album: Identifiable {
    let id = UUID()
    let createdAt: Date = Date.now
    var modifiedAt: Date = Date.now
    
    var title: String
    var artists: [Artist]
    var releaseDate: Date?
    var cover: URL?
    
    
    init(title: String = "", artists: [Artist] = [],
         releaseDate: Date? = nil, cover: URL? = nil) {
        self.title = title
        self.artists = artists
        self.releaseDate = releaseDate
        self.cover = cover
    }
}

extension Album: Equatable {
    static func == (lhs: Album, rhs: Album) -> Bool {
        return lhs.id == rhs.id
    }
}

