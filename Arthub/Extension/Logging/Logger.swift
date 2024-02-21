//
//  Logger.swift
//  Arthub
//
//  Created by 张鸿燊 on 21/2/2024.
//

import Foundation
import Logging

extension Logger {
    
    static let shared = Logger(label: "com.hanson.Arthub")
    
    static func debug(_ message: Message, metadata: Metadata?, source: String?) {
        shared.debug(message, metadata: metadata, source: source)
    }
    
    static func info(_ message: Message, metadata: Metadata?, source: String?) {
        shared.info(message, metadata: metadata, source: source)
    }
    
    static func warning(_ message: Message, metadata: Metadata?, source: String?) {
        shared.warning(message, metadata: metadata, source: source)
    }
    
    static func error(_ message: Message, metadata: Metadata?, source: String?) {
        shared.error(message, metadata: metadata, source: source)
    }
    
    static func trace(_ message: Message, metadata: Metadata?, source: String?) {
        shared.trace(message, metadata: metadata, source: source)
    }
    
    static func critical(_ message: Message, metadata: Metadata?, source: String?) {
        shared.critical(message, metadata: metadata, source: source)
    }
}
