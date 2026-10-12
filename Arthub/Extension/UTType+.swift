//
//  UTType+.swift
//  Arthub
//
//  Created by 张鸿燊 on 13/2/2024.
//

import UniformTypeIdentifiers

extension UTType {
    
    static let ttml = UTType("com.zhanghongshen.ttml")!
    
    /// Whichever type the system gives `.lrc`, so files typed by another app's declaration still match.
    static let lrc = UTType(filenameExtension: "lrc") ?? .plainText
}
