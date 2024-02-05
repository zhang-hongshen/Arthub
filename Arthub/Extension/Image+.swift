//
//  Image+.swift
//  Arthub
//
//  Created by 张鸿燊 on 5/2/2024.
//

import Foundation
import SwiftUI

extension Image {
    init?(data: Data){
        guard let nsImage = NSImage(data: data) else {
            return nil
        }
        self.init(nsImage: nsImage)
    }
}
