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
    @Attribute(.unique) var id = UUID()
    
    var name: String
    var artist: String
    var releaseYear: String
    
    @Relationship(deleteRule:.noAction, inverse: \Music.album)
    var music = [Music]()
    
    init(name: String = "", artist: String = "", releaseYear: String = "") {
        self.name = name
        self.artist = artist
        self.releaseYear = releaseYear
    }
}
