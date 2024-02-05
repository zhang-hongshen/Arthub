//
//  TimeInterval.swift
//  shelf
//
//  Created by 张鸿燊 on 1/2/2024.
//

import Foundation


extension TimeInterval {
    func formatted(_ format: NSCalendar.Unit) -> String {
        let formatter = DateComponentsFormatter.shard
        formatter.allowedUnits = format
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: self)!
    }
}
