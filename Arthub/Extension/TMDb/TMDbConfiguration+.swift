//
//  TMDbConfiguration+.swift
//  Arthub
//
//  Created by 张鸿燊 on 17/2/2024.
//

import Foundation
import TMDb

extension TMDbConfiguration {
    static func configure(apiKey: String) {
        configure(TMDbConfiguration(apiKey: apiKey))
    }
}
 
