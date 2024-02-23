//
//  Movie.swift
//  Arthub
//
//  Created by 张鸿燊 on 17/2/2024.
//

import Foundation
import SwiftData


@Model
class MovieMetrics: Identifiable {
    @Attribute(.unique) let id = UUID()
    
    var createdAt: Date = Date.now
    var watchedAt: Date? = nil
    
    var tmdbID: Int?
    var imdbID: String?
    
    var currentTime: TimeInterval = 0
    var progress: Double = 0
    
    init(tmdbID: Int? = nil, imdbID: String? = nil) {
        self.tmdbID = tmdbID
        self.imdbID = imdbID
    }
    
}

extension MovieMetrics {
    func setProgress(_ progress: Double) {
        self.progress = progress.clamp(to: 0...1)
        watchedAt = Date.now
    }
}
