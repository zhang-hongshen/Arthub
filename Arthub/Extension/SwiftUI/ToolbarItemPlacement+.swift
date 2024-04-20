//
//  ToolbarItemPlacement+.swift
//  Arthub
//
//  Created by 张鸿燊 on 14/3/2024.
//

import SwiftUI

extension ToolbarItemPlacement {
    #if os(macOS)
    static let music = accessoryBar(id: "com.arthub.music")
    #endif
}

