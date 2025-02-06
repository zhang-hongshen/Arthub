//
//  DisplayResolution.swift
//  Arthub
//
//  Created by 张鸿燊 on 18/2/2024.
//

import Foundation

enum VideoResolution: CaseIterable, Identifiable {
    case s4k
    case s1080
    case s720
    case s480
    case s360
    
    var id: Self { self }
    
    var localizedName: String {
        switch self {
        case .s4k:
            "4K"
        case .s1080:
            "1080p"
        case .s720:
            "720p"
        case .s480:
            "480p"
        case .s360:
            "360p"
        }
    }
    
    init(size: CGSize) {
        if size.width >= 3840 && size.height >= 2160 {
            self = .s4k
        } else if size.width >= 1920 && size.height >= 1080 {
            self = .s1080
        } else if size.width >= 1280 && size.height >= 720 {
            self = .s720
        } else if size.width >= 640 && size.height >= 480 {
            self = .s480
        } else if size.width >= 640 && size.height >= 360 {
            self = .s360
        } else {
            self = .s360
        }
    }
}


