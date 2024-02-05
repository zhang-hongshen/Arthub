//
//  Movie.swift
//  shelf
//
//  Created by 张鸿燊 on 31/1/2024.
//

import Foundation
import SwiftData

@Model
class Movie {
    @Attribute(.unique) let id = UUID()
    let createdAt: Date = Date.now
    var modifiedAt: Date = Date.now
    
    var name: String
    var filepath: String
    var thumbnail: String
    var releaseYear: String
    
    // User Metrics
    var currentTime: TimeInterval
    var progress: Double
    var count: Int64
    
    init(name: String = "" , filepath: String = "", thumbnail: String = "",
         releaseYear: String = "", currentTime: TimeInterval = 0, progress: Double = 0, count: Int64 = 0) {
        self.name = name
        self.filepath = filepath
        self.thumbnail = thumbnail
        self.releaseYear = releaseYear
        self.currentTime = currentTime
        self.progress = progress
        self.count = count
    }
    
}

extension Movie: Hashable {
    static func == (lhs: Movie, rhs: Movie) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Movie {
    static public func examples() -> [Movie] {
        return [
            Movie(name: "流星花园1", thumbnail: "movie_1", releaseYear: "2023", currentTime: 30, progress: 0.75),
            Movie(name: "流星花园2", thumbnail: "movie_1", releaseYear: "2023"),
            Movie(name: "流星花园3", thumbnail: "movie_1", releaseYear: "2023", currentTime: 30, progress: 0.75),
            Movie(name: "流星花园4", thumbnail: "movie_1", releaseYear: "2023"),
            Movie(name: "速度与激情1", thumbnail: "movie_2", releaseYear: "2023"),
            Movie(name: "速度与激情2", thumbnail: "movie_2", releaseYear: "2023"),
            Movie(name: "速度与激情3", thumbnail: "movie_2", releaseYear: "2023"),
            Movie(name: "速度与激情4", thumbnail: "movie_2", releaseYear: "2023"),
            Movie(name: "变形记1", thumbnail: "movie_3", releaseYear: "2023"),
            Movie(name: "变形记2", thumbnail: "movie_3", releaseYear: "2023"),
            Movie(name: "变形记3", thumbnail: "movie_3", releaseYear: "2023"),
            Movie(name: "变形记4", thumbnail: "movie_3", releaseYear: "2023"),
            Movie(name: "变形金刚1", thumbnail: "movie_4", releaseYear: "2023"),
            Movie(name: "变形金刚2", thumbnail: "movie_4", releaseYear: "2023"),
            Movie(name: "变形金刚3", thumbnail: "movie_4", releaseYear: "2023"),
            Movie(name: "变形金刚4", thumbnail: "movie_4", releaseYear: "2023"),
            Movie(name: "奥特曼1", thumbnail: "movie_5", releaseYear: "2023"),
            Movie(name: "奥特曼2", thumbnail: "movie_5", releaseYear: "2023"),
            Movie(name: "奥特曼3", thumbnail: "movie_5", releaseYear: "2023"),
            Movie(name: "奥特曼4", thumbnail: "movie_5", releaseYear: "2023")
        ]
    }
}
