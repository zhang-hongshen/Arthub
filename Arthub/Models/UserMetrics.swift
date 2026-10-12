//
//  UserMetrics.swift
//  Arthub
//
//  Created by 张鸿燊 on 17/2/2024.
//

import Foundation
import SwiftData

/// TMDb numbers movies and episodes separately, so an ID needs its kind to be unique.
enum MediaKind: String {
    case movie, episode
}

/// Watch progress for one movie or episode.
@Model
final class UserMetrics {
    /// `movie/603` or `episode/63056`.
    @Attribute(.unique) var key: String
    var kind: String
    var tmdbID: Int

    var createdAt: Date = Date.now
    var watchedAt: Date? = nil
    var currentTime: TimeInterval = 0

    init(_ kind: MediaKind, tmdbID: Int) {
        self.key = "\(kind.rawValue)/\(tmdbID)"
        self.kind = kind.rawValue
        self.tmdbID = tmdbID
    }
}

/// Saves watch progress. Kept in memory while developing; release builds keep it at
/// `Application Support/Arthub/Arthub.store`.
@MainActor
final class WatchProgressStore {
    static let shared = WatchProgressStore()

    let container: ModelContainer
    /// Every row by key, fetched once so a library scan doesn't query per file.
    private var rows: [String: UserMetrics] = [:]

    init() {
        #if DEBUG
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        #else
        let configuration = ModelConfiguration(url: URL.applicationSupportDirectory.appending(path: "Arthub/Arthub.store"))
        #endif
        // If the file can't be opened, progress lasts until the app quits.
        container = (try? ModelContainer(for: UserMetrics.self, configurations: configuration))
            ?? (try! ModelContainer(for: UserMetrics.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let saved = (try? container.mainContext.fetch(FetchDescriptor<UserMetrics>())) ?? []
        for row in saved { rows[row.key] = row }
    }

    /// The row for an item, inserted on first use.
    func metrics(_ kind: MediaKind, tmdbID: Int) -> UserMetrics {
        let key = "\(kind.rawValue)/\(tmdbID)"
        if let row = rows[key] { return row }
        let row = UserMetrics(kind, tmdbID: tmdbID)
        container.mainContext.insert(row)
        rows[key] = row
        return row
    }

    /// Players call this every few seconds of playback, and when playback pauses or ends.
    func record(_ time: TimeInterval, for metrics: UserMetrics) {
        metrics.currentTime = time
        // Only actual playback marks the item as watched.
        if time > 0 { metrics.watchedAt = .now }
        try? container.mainContext.save()
    }
}
