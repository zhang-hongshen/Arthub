//
//  PlatformImage.swift
//  Arthub
//
//  Created by 张鸿燊 on 24/3/2024.
//

#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#endif
