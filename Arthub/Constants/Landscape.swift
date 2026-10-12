//
//  Landscape.swift
//  Arthub
//
//  Created by 张鸿燊 on 1/3/2024.
//

import Foundation

/// Backdrop and episode still sizes.
enum Landscape {
    static let aspectRatio: CGFloat = 1.4

    enum Size {
        case small, regular
    }

    static func height(_ size: Size = .regular) -> CGFloat {
        size == .small ? 100 : 200
    }
}
