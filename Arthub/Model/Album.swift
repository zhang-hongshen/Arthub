//
//  Album.swift
//  Arthub
//
//  Created by 张鸿燊 on 4/2/2024.
//

import Foundation
import SwiftData


@Model
class Album {
    @Attribute(.unique) let id = UUID()
    let createdAt: Date = Date.now
    var modifiedAt: Date = Date.now
    
    var name: String
    var artist: String
    var releaseYear: String
    
    @Relationship(deleteRule:.noAction, inverse: \Music.album)
    var music: [Music] = []
    
    init(name: String = "", artist: String = "", releaseYear: String = "") {
        self.name = name
        self.artist = artist
        self.releaseYear = releaseYear
    }
}

extension Album: Hashable {
    static func == (lhs: Album, rhs: Album) -> Bool {
        return lhs.id == rhs.id
    }
}
