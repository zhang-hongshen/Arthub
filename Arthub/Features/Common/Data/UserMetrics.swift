//
//  Movie.swift
//  Arthub
//
//  Created by 张鸿燊 on 17/2/2024.
//

import Foundation
import SwiftData

@Model
class UserMetrics: Identifiable {
    @Attribute(.unique) let id = UUID()
    
    var createdAt: Date = Date.now
    var watchedAt: Date? = nil
    
    var tmdbID: Int?
    var imdbID: String?
    
    var currentTime: TimeInterval = 0 {
        didSet {
            watchedAt = .now
        }
    }
    
    init(tmdbID: Int? = nil, imdbID: String? = nil) {
        self.tmdbID = tmdbID
        self.imdbID = imdbID
    }
    
}

extension UserMetrics {
    
    static private func getByTMDbIDFetchDescriptor(_ tmdbID: Int) -> FetchDescriptor<UserMetrics> {
        let predicate = #Predicate<UserMetrics> {
            if let tmdbID = $0.tmdbID {
                return tmdbID == tmdbID
            } else {
                return false
            }
        }
        
        return FetchDescriptor<UserMetrics>(
            predicate: predicate,
            sortBy: [
                .init(\.createdAt)
            ]
        )
    }
    
    static func getByTMDbID(_ tmdbID: Int) async throws -> UserMetrics {
        let res = try await CachedDataHandler.shared.fetch(getByTMDbIDFetchDescriptor(tmdbID))

        guard let tmp = res.first else {
            let metrics = UserMetrics(tmdbID: tmdbID)
            try await CachedDataHandler.shared.insert(metrics)
            return metrics
        }
        return tmp
    }
}
