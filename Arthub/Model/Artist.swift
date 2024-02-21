//
//  Artist.swift
//  Arthub
//
//  Created by 张鸿燊 on 21/2/2024.
//

import Foundation

class Artist: Identifiable {
    let id = UUID()
    
    var name: String
    var profiles: [URL]
    
    init(name: String = "", profiles: [URL] = []) {
        self.name = name
        self.profiles = profiles
    }
}
