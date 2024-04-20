//
//  Image+.swift
//  Arthub
//
//  Created by 张鸿燊 on 21/3/2024.
//

import SwiftUI

extension Image {
    init?(data: Data) {
        #if canImport(AppKit)
        guard let image = NSImage(data: data) else { return nil }
        self.init(nsImage: image)
        #elseif canImport(UIKit)
        guard let image = UIImage(data: data) else { return nil }
        self.init(uiImage: image)
        #endif
    }
}
