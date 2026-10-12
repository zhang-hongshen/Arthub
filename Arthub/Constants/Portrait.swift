//
//  Portrait.swift
//  Arthub
//
//  Created by 张鸿燊 on 1/3/2024.
//

import Foundation

/// Poster sizes.
enum Portrait {
    static let aspectRatio: CGFloat = 0.75

    enum Size {
        case small, regular
    }

    static func width(_ size: Size = .regular) -> CGFloat {
        size == .small ? 150 : 210
    }

    static func height(_ size: Size = .regular) -> CGFloat {
        width(size) / aspectRatio
    }
}
