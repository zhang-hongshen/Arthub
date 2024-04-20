//
//  ShapeStyle+.swift
//  Arthub
//
//  Created by 张鸿燊 on 19/3/2024.
//

import SwiftUI

extension ShapeStyle where Self == Color {
    
    static var random : Color {
        [.accent, .cyan, .indigo, .mint, .teal].randomElement()!
    }
}
