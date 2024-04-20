//
//  TVShowOrder.swift
//  Arthub
//
//  Created by 张鸿燊 on 28/2/2024.
//

import Foundation
import SwiftUI

enum TVShowOrderProperty: String, CaseIterable, Identifiable {
    case title, popularity
    var id: Self { self }
    
    var localizedKey: LocalizedStringKey {
        switch self {
        case .title:
            LocalizedStringKey("Title")
        case .popularity:
            LocalizedStringKey("Popularity")
        }
    }
}
