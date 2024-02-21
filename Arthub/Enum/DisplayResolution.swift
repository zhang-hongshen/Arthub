//
//  DisplayResolution.swift
//  Arthub
//
//  Created by 张鸿燊 on 18/2/2024.
//

import Foundation

enum DisplayResolution: String, CaseIterable, Identifiable {
    case uhd = "4K"
    case fhd = "1080p"
    case hd = "720p"
    case ed = "480p"
    case sd = "360p"
    case unknown = "Unknown"
    
    var id: Self { self }
}


