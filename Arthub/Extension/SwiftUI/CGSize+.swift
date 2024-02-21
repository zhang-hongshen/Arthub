//
//  CGSize+.swift
//  Arthub
//
//  Created by 张鸿燊 on 18/2/2024.
//

import Foundation

extension CGSize {
    func toDisplayResolution() -> DisplayResolution {
            
        if width >= 3840 && height >= 2160 {
            return .uhd
        } else if width >= 1920 && height >= 1080 {
            return .fhd
        } else if width >= 1280 && height >= 720 {
            return .hd
        } else if width >= 640 && height >= 480 {
            return .ed
        } else if width >= 640 && height >= 360 {
            return .sd
        }
        return .unknown
    }
}
