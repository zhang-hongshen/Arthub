//
//  MovieOrder.swift
//  Arthub
//
//  Created by 张鸿燊 on 27/2/2024.
//

import SwiftUI

enum MovieOrderProperty: String, CaseIterable, Identifiable {
    case title, popularity, releaseDate, createdAt, watchedAt
    var id: Self { self }
    
    var localizedKey: LocalizedStringKey {
        switch self {
        case .title:
            LocalizedStringKey("Title")
        case .popularity:
            LocalizedStringKey("Popularity")
        case .releaseDate:
            LocalizedStringKey("Date Released")
        case .createdAt:
            LocalizedStringKey("Date Added")
        case .watchedAt:
            LocalizedStringKey("Date Watched")
        
        }
    }
}
