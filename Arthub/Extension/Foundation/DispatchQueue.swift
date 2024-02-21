//
//  DispatchQueue.swift
//  Arthub
//
//  Created by 张鸿燊 on 14/2/2024.
//

import Foundation

extension DispatchQueue {
    static private let label = "com.hanson.Arthub"
    
    static let userInteractive = DispatchQueue(label: label, qos: .userInteractive, attributes:  .concurrent)
    static let userInitiated = DispatchQueue(label: label, qos: .userInitiated, attributes: .concurrent)
    static let utility = DispatchQueue(label: label, qos: .utility, attributes: .concurrent)
    static let background = DispatchQueue(label: label, qos: .background, attributes: .concurrent)
}
