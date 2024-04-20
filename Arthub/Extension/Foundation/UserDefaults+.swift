//
//  UserDefaults.swift
//  Arthub
//
//  Created by 张鸿燊 on 3/2/2024.
//
import Foundation

extension UserDefaults {
    // General
    static let appearance = "appearance"
    
    // Storage
    static let localMoviesData = "localMoviesData"
    static let localTVShowsData = "localTVShowsData"
    static let localMusicData = "localMusicData"
    
    func value<T>(forKey key: String, default defaultValue: T) -> T {
        return self.value(forKey: key) as? T ?? defaultValue
    }
    
    func append<T>(forKey key: String, newElement: T) {
        var array: [T] = value(forKey: key, default: [])
        array.append(newElement)
        setValue(array, forKey: key)
    }
}


enum Appearance: String {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var id: Self { self }
}

