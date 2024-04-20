//
//  MusicOrder.swift
//  Arthub
//
//  Created by 张鸿燊 on 27/2/2024.
//

import SwiftUI

enum MusicOrderProperty: String, CaseIterable, Identifiable {
    case title, artistName, albumTitle, releaseDate, createdAt
    var id: Self { self }
    
    var localizedKey: LocalizedStringKey {
        switch self {
        case .title:
            LocalizedStringKey("Title")
        case .artistName:
            LocalizedStringKey("Artist")
        case .albumTitle:
            LocalizedStringKey("Album")
        case .releaseDate:
            LocalizedStringKey("Date Released")
        case .createdAt:
            LocalizedStringKey("Date Added")
        }
    }
}
