//
//  NetEase.swift
//  Arthub
//

import Foundation

/// Word-by-word lyrics (`yrc`) from NetEase Cloud Music, free and without an account.
enum NetEase {

    struct Track: Decodable {
        struct Artist: Decodable { var name: String }
        var id: Int
        var name: String
        var artists: [Artist]
        /// In milliseconds.
        var duration: TimeInterval
    }

    private struct SearchResponse: Decodable {
        struct Result: Decodable { var songs: [Track]? }
        var result: Result?
    }

    private struct LyricResponse: Decodable {
        struct Text: Decodable { var lyric: String? }
        var yrc: Text?
    }

    /// Word-timed lyrics of the same recording: the same title and artist, about as long. Empty without any.
    static func lyrics(title: String, artist: String, duration: TimeInterval) async throws -> [Lyric] {
        let text = [title, artist].filter { !$0.isEmpty }.joined(separator: " ")
        let response: SearchResponse = try await request("search/get/web", query: [
            URLQueryItem(name: "s", value: text), URLQueryItem(name: "type", value: "1"),
            URLQueryItem(name: "limit", value: "10")])
        let tracks = (response.result?.songs ?? []).filter { $0.matches(title: title, artist: artist, duration: duration) }
        // Another release of the song may have word timing when the first doesn't.
        for track in tracks.prefix(3) {
            let response: LyricResponse = try await request("song/lyric", query: [
                URLQueryItem(name: "id", value: String(track.id)), URLQueryItem(name: "yv", value: "-1")])
            let found = lyrics(yrc: response.yrc?.lyric ?? "")
            if !found.isEmpty { return found }
        }
        return []
    }

    /// `[start,duration](start,duration,0)word(start,duration,0)word…` lines in milliseconds.
    /// Credits such as `作词 : …` are left out.
    static func lyrics(yrc text: String) -> [Lyric] {
        let seconds = { (value: Substring) in (TimeInterval(value) ?? 0) / 1000 }
        let lines = text.split(separator: "\n").compactMap { line -> Lyric? in
            guard let header = line.prefixMatch(of: /\[(\d+),(\d+)\]/) else { return nil }
            let rest = line[header.range.upperBound...]
            let tags = rest.matches(of: /\((\d+),(\d+),-?\d+\)/)
            let words = tags.indices.map { index in
                let tag = tags[index]
                let start = seconds(tag.output.1)
                let end = index + 1 < tags.count ? tags[index + 1].range.lowerBound : rest.endIndex
                return (start: start, end: start + seconds(tag.output.2), text: rest[tag.range.upperBound..<end])
            }
            let content = words.map { $0.text }.joined().trimmingCharacters(in: .whitespaces)
            // Credits are timed as a single word.
            guard !content.isEmpty, !(words.count == 1 && content.contains(/[:：]/)) else { return nil }
            let phrases = words.compactMap { word -> Lyric? in
                let text = word.text.trimmingCharacters(in: .whitespaces)
                return text.isEmpty ? nil : Lyric(start: word.start, end: word.end, content: text)
            }
            let start = seconds(header.output.1)
            return Lyric(start: start, end: start + seconds(header.output.2), content: content, phrases: phrases)
        }
        // A line held past the next one ends when it starts.
        for (line, next) in zip(lines, lines.dropFirst()) where next.start > line.start {
            line.end = min(line.end, next.start)
        }
        return lines
    }

    private static func request<Response: Decodable>(_ endpoint: String, query: [URLQueryItem]) async throws -> Response {
        let url = URL(string: "https://music.163.com/api")!.appending(path: endpoint).appending(queryItems: query)
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 15))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}

extension NetEase.Track {

    /// Timing only fits a recording of about the same length; an unknown artist matches any.
    func matches(title: String, artist: String, duration: TimeInterval) -> Bool {
        guard !title.matchKey.isEmpty, name.matchKey == title.matchKey else { return false }
        if duration > 0, abs(self.duration / 1000 - duration) > 3 { return false }
        return artist.isEmpty || artists.contains { $0.name.isSameArtist(as: artist) }
    }
}
