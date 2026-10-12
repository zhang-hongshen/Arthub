//
//  LRCLIB.swift
//  Arthub
//

import Foundation

/// Lyrics from LRCLIB (lrclib.net), a free and open lyrics database with time-synced LRC.
enum LRCLIB {

    struct Record: Decodable, Identifiable {
        var id: Int
        var trackName: String
        var artistName: String
        var albumName: String?
        var duration: TimeInterval?
        var instrumental: Bool
        var plainLyrics: String?
        var syncedLyrics: String?

        var isSynced: Bool { !(syncedLyrics ?? "").isEmpty }
        var hasLyrics: Bool { isSynced || !(plainLyrics ?? "").isEmpty }

        /// Time-synced lyrics when there are any, otherwise plain lines.
        var lyrics: [Lyric] {
            let synced = SidecarParser.lyrics(lrc: syncedLyrics ?? "")
            return synced.isEmpty ? plainLines : synced
        }

        /// The words alone, for a recording whose timing would be off.
        var plainLines: [Lyric] {
            if let plainLyrics, !plainLyrics.isEmpty {
                return SidecarParser.lyrics(text: plainLyrics)
            }
            return SidecarParser.lyrics(lrc: syncedLyrics ?? "").map { Lyric(content: $0.content) }
        }
    }

    /// Lyrics for a song: the exact title, artist, album and length first, then the closest search result.
    /// Timing is only taken from a recording of about the same length.
    static func lyrics(title: String, artist: String, album: String, duration: TimeInterval) async throws -> [Lyric] {
        var query = [URLQueryItem(name: "track_name", value: title)]
        if !artist.isEmpty { query.append(URLQueryItem(name: "artist_name", value: artist)) }
        if duration > 0 {
            var exact = query
            if !album.isEmpty { exact.append(URLQueryItem(name: "album_name", value: album)) }
            exact.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded()))))
            // A busy server only skips straight to searching.
            if let record: Record = try? await request("get", query: exact), record.hasLyrics {
                return record.lyrics
            }
        }
        let results: [Record] = try await request("search", query: query) ?? []
        var records = results.filter(\.hasLyrics)
        // An artist written differently, such as `周杰倫 Jay Chou` for 周杰伦, finds nothing; the title alone does.
        if records.isEmpty, !artist.isEmpty {
            let byTitle: [Record] = try await request("search", query: [URLQueryItem(name: "track_name", value: title)]) ?? []
            records = byTitle.filter { $0.hasLyrics && $0.artistName.isSameArtist(as: artist) }
        }
        let distance = { (record: Record) in abs((record.duration ?? 0) - duration) }
        let sameLength = records.filter { $0.isSynced && duration > 0 && distance($0) <= 3 }
        if let record = sameLength.min(by: { distance($0) < distance($1) }) {
            return record.lyrics
        }
        return records.min { distance($0) < distance($1) }?.plainLines ?? []
    }

    /// nil when LRCLIB has no such track.
    private static func request<Response: Decodable>(_ endpoint: String, query: [URLQueryItem]) async throws -> Response? {
        let url = URL(string: "https://lrclib.net/api")!.appending(path: endpoint).appending(queryItems: query)
        var request = URLRequest(url: url, timeoutInterval: 15)
        // LRCLIB asks clients to name themselves.
        request.setValue("Arthub (https://github.com/zhang-hongshen/Arthub)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        switch (response as? HTTPURLResponse)?.statusCode {
        case 200: return try JSONDecoder().decode(Response.self, from: data)
        case 404: return nil
        default: throw URLError(.badServerResponse)
        }
    }
}
