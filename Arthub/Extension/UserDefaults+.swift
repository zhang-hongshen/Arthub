//
//  UserDefaults.swift
//  Arthub
//
//  Created by 张鸿燊 on 3/2/2024.
//

import Foundation

extension UserDefaults {
    enum Settings: String {
        case appearance = "appearance"
    }
    
    enum LibraryLocation: String {
        case movie = "Movie/"
        case music = "Music/"
    }
}
