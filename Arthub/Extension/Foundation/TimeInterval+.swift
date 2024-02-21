//
//  TimeInterval.swift
//  shelf
//
//  Created by 张鸿燊 on 1/2/2024.
//

import Foundation

extension TimeInterval {
    func formatted(unitsStyle: DateComponentsFormatter.UnitsStyle = .positional,
                   zeroFormattingBehavior: DateComponentsFormatter.ZeroFormattingBehavior = .pad) -> String {
        var defaultFormat: NSCalendar.Unit {
            if self < 3600 {
                return [.minute, .second]
            }
            return [.hour, .minute, .second]
        }
        let formatter = DateComponentsFormatter.shard
        formatter.allowedUnits = defaultFormat
        formatter.unitsStyle = unitsStyle
        formatter.zeroFormattingBehavior = zeroFormattingBehavior

        return formatter.string(from: self) ?? ""
    }
}
