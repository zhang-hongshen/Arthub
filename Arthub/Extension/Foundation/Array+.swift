//
//  Array+.swift
//  Arthub
//
//  Created by 张鸿燊 on 16/2/2024.
//

import Foundation

extension Array: RawRepresentable where Element: Codable {
    
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Element].self, from: data)
        else {
            return nil
        }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return result
    }
}

extension Array where Element: ArtistDetail {
    
    func formatted() -> String {
        return self.map{ $0.name }.joined(separator: " & ")
    }
}
