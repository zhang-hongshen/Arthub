//
//  TimeInterval.swift
//  shelf
//
//  Created by 张鸿燊 on 1/2/2024.
//

import Foundation

extension TimeInterval {

    private static let formatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    /// `3:05`, or `1:02:03` from an hour on.
    func formatted() -> String {
        let formatter = Self.formatter
        formatter.allowedUnits = self < 3600 ? [.minute, .second] : [.hour, .minute, .second]
        return formatter.string(from: self) ?? ""
    }
}
