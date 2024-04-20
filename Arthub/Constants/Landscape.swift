//
//  Landscape.swift
//  Arthub
//
//  Created by 张鸿燊 on 1/3/2024.
//

import Foundation

struct Landscape {
    static let aspectRatio: CGFloat = 1.4
    
    enum LandscapeSize {
        case mini, small, regular, large, extraLarge
    }
    
    static func height(_ size: LandscapeSize = .regular) -> CGFloat {
        switch size {
        case .mini:
            50
        case .small:
            100
        case .regular:
            200
        case .large:
            400
        case .extraLarge:
            600
        }
    }
}
