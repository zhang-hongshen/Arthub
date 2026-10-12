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
    static let language = "language"
    
    // Storage
    static let library = "library"

    /// Folders scanned until the list is first changed: the user's Movies and Music folders on macOS.
    static var defaultLibraries: [String] {
        #if os(macOS)
        [URL.moviesDirectory, URL.musicDirectory].map(\.absoluteString)
        #else
        []
        #endif
    }

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

enum Language: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    
    var id: Self { self }
    
    /// Locale injected into the SwiftUI environment so views relocalize immediately.
    var locale: Locale {
        switch self {
        case .system:   Locale(identifier: Locale.preferredLanguages.first ?? Locale.current.identifier)
        default:        Locale(identifier: rawValue)
        }
    }
    
    /// Persists the choice as `AppleLanguages` so Foundation lookups
    /// (`String(localized:)`, system menus) follow it after relaunch.
    func applyToBundle() {
        switch self {
        case .system:   UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        default:        UserDefaults.standard.set([rawValue], forKey: "AppleLanguages")
        }
    }
}
