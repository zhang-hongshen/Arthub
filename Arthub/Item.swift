//
//  Item.swift
//  Arthub
//
//  Created by 张鸿燊 on 2/2/2024.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
