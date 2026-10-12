//
//  UIDevice+.swift
//  Arthub
//
//  Created by 张鸿燊 on 6/3/2024.
//

#if canImport(UIKit)
import UIKit

extension UIDevice {
    static var isIPhone: Bool {
        current.userInterfaceIdiom == .phone
    }
}
#endif
