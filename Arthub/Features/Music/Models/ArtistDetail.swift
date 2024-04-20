//
//  ArtistDetail.swift
//  Arthub
//
//  Created by 张鸿燊 on 21/2/2024.
//

import Foundation

@Observable
class ArtistDetail: Identifiable, Hashable {
    let id = UUID()
    
    var name: String
    var profile: URL?
    
    init(name: String = "", profile: URL? = nil) {
        self.name = name
        self.profile = profile
    }
    
    static func == (lhs: ArtistDetail, rhs: ArtistDetail) -> Bool {
        return lhs.name == rhs.name
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}
