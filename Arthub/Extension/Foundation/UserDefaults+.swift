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
    
    static let movieMetadata = "movieMetadata"
    static let musicMetadata = "musicMetadata"
    
    // Storage
    static let localMovieData = "localMovieData"
    static let localTVShowData = "localTVShowData"
    static let localMusicData = "localMusicData"
}


enum Appearance: String {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var id: Self { self }
}

enum MovieMetadata: String {
    case local = "local"
    case tmdb = "tmdb"
}

enum MusicMetadata: String {
    case local = "local"
    case musicbrainz = "musicbrainz"
}


struct Storage {
    
    static var defaultLocalMovieData: String {
        do {
            return try FileManager.default.url(for: .moviesDirectory, 
                                               in: .userDomainMask,
                                               appropriateFor: nil,
                                               create: true).appending(component: "Arthub").relativeString
        } catch {
            
        }
        return ""
    }
    
    static var defaultLocalMusicData: String {
        do {
            return try FileManager.default.url(for: .musicDirectory,
                                               in: .userDomainMask,
                                               appropriateFor: nil,
                                               create: true).appending(component: "Arthub").relativeString
        }
        catch {
        }
        return ""
    }
    
    static var defaultLocalTVShowData: String {
        do {
            return try FileManager.default.url(for: .userDirectory,
                                               in: .userDomainMask,
                                               appropriateFor: nil,
                                               create: true)
            .appending(component: "TVShows")
            .appending(component: "Arthub").relativeString
        }
        catch {
        }
        return ""
    }
}
