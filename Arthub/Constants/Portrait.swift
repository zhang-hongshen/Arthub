//
//  Portrait.swift
//  Arthub
//
//  Created by 张鸿燊 on 1/3/2024.
//

import Foundation


struct Portrait {
    static let aspectRatio: CGFloat = 0.75
    
    enum PortraitSize: Identifiable {
        case mini, small, regular, large, extraLarge
        var id: Self { self }
    }
    
    static func width(_ size: PortraitSize = .regular) -> CGFloat {
        switch size {
        case .mini:
            60
        case .small:
            150
        case .regular:
            210
        case .large:
            375
        case .extraLarge:
            525
        }
    }
    
    static func height(_ size: PortraitSize = .regular) -> CGFloat {
        width(size) / aspectRatio
    }
}
