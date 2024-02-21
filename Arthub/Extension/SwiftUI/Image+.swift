//
//  Image+.swift
//  Arthub
//
//  Created by 张鸿燊 on 5/2/2024.
//
import SwiftUI

extension Image {

    init(data: Data?, defaultSystemName: String){
        if let data = data,
           let nsImage = NSImage(data: data) {
            self.init(nsImage: nsImage)
        } else {
            self.init(systemName: defaultSystemName)
        }
    }
}
