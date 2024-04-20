//
//  FeedDetail.swift
//  Arthub
//
//  Created by 张鸿燊 on 15/3/2024.
//

import Foundation
import SwiftData

@Model
class FeedDetail: Identifiable {
    @Attribute(.unique) let id = UUID()
    let createdAt = Date.now
    
    var title: String
    var url: String
    
    init(title: String = "", url: String = "") {
        self.title = title
        self.url = url
    }
}

extension FeedDetail {
    
    static private func listAllFetchDescriptor() -> FetchDescriptor<FeedDetail> {
        let predicate = #Predicate<FeedDetail> { _ in
            true
        }
        
        return FetchDescriptor<FeedDetail>(
            predicate: predicate,
            sortBy: [
                .init(\.createdAt)
            ]
        )
    }
    
    static func listAll() async throws -> [FeedDetail] {
        return try await CachedDataHandler.shared.fetch(listAllFetchDescriptor())
    }
}
