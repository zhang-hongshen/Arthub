//
//  UIDevice+.swift
//  Arthub
//
//  Created by 张鸿燊 on 6/3/2024.
//

#if canImport(UIKit)
import UIKit

extension UIDevice {
    
    #if os(iOS)
    class var isIPad: Bool {
        current.userInterfaceIdiom == .pad
    }
    class var isIPhone: Bool {
        current.userInterfaceIdiom == .phone
    }
    
    class var isLanscape: Bool {
        .landscapeLeft == current.orientation
        || .landscapeRight == current.orientation
    }
    
    class var isPortrait: Bool {
        .portrait == current.orientation
        || .portraitUpsideDown == current.orientation
    }
    #endif
}
#endif
