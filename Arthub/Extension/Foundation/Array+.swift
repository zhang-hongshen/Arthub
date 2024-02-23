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

extension Array where Element: Identifiable {
    
    func nextId(after id: Element.ID) -> Element.ID? {
        guard let index = self.firstIndex(where: { $0.id == id }) else {
            return nil // 如果找不到给定id，则返回nil
        }
        
        let nextIndex = index + 1
        if nextIndex < self.count {
            return self[nextIndex].id // 返回下一个元素的id
        }
        return nil
    }
    
}

extension Array where Element: Artist {
    
    func formatted() -> String {
        return self.map{ $0.name }.joined(separator: " & ")
    }
}
