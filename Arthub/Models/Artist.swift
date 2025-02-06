//
//  ArtistDetail.swift
//  Arthub
//
//  Created by 张鸿燊 on 21/2/2024.
//

import Foundation

@Observable
class Artist: Identifiable, Hashable {
    let id = UUID()
    
    var name: String
    var profile: URL?
    var albums: [Album] = []
    
    init(name: String = "", profile: URL? = nil, albums: [Album] = []) {
        self.name = name
        self.profile = profile
        self.albums = albums
    }
    
    static func == (lhs: Artist, rhs: Artist) -> Bool {
        return lhs.name == rhs.name
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}
