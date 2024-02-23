//
//  FileManager+.swift
//  Arthub
//
//  Created by 张鸿燊 on 21/2/2024.
//

import Foundation


extension FileManager {
    
    func fileExists(at: URL) -> Bool {
        return FileManager.default.fileExists(atPath: at.relativePath)
    }
}
