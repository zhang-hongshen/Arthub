//
//  String+.swift
//  Arthub
//
//  Created by 张鸿燊 on 14/2/2024.
//
import Foundation

extension String: Identifiable {
    
    public typealias ID = Int
    public var id: Int {
        return hash
    }
}
