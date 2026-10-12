//
//  Lyric.swift
//  Arthub
//
//  Created by 张鸿燊 on 2/2/2024.
//

import Foundation

@Observable
class Lyric: Identifiable, Equatable {
    let id = UUID()
    var start: TimeInterval
    var end: TimeInterval
    var content:  String
    var phrases: [Lyric] = []
    
    init(start: TimeInterval = 0, end: TimeInterval = 0,
         content: String = "", phrases: [Lyric] = []) {
        self.start = start
        self.end = end
        self.content = content
        self.phrases = phrases
    }
    
    static func == (lhs: Lyric, rhs: Lyric) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: Computed Property

extension Lyric {
    var duration: TimeInterval {
        end - start
    }

    func isActive(at time: TimeInterval) -> Bool {
        start <= time && time < end
    }

    /// Moves the line and its words; a negative offset is earlier. Times before zero are written as zero.
    func shift(by offset: TimeInterval) {
        start += offset
        end += offset
        phrases.forEach { $0.shift(by: offset) }
    }

    /// The line split into its timed words and the text between them; nil without word timing,
    /// or once edited words no longer match the line.
    var segments: [(text: Substring, phrase: Lyric?)]? {
        guard !phrases.isEmpty else { return nil }
        let content = self.content
        var segments: [(text: Substring, phrase: Lyric?)] = []
        var cursor = content.startIndex
        for phrase in phrases where !phrase.content.isEmpty {
            guard let range = content.range(of: phrase.content, range: cursor..<content.endIndex) else { return nil }
            if cursor < range.lowerBound { segments.append((content[cursor..<range.lowerBound], nil)) }
            segments.append((content[range], phrase))
            cursor = range.upperBound
        }
        if cursor < content.endIndex { segments.append((content[cursor...], nil)) }
        return segments
    }
}

extension Lyric {
    
    static func loadLyrics(url: URL) -> [Lyric] {
        if url.isTTML {
            return TTMLParser().parse(url: url)
        }
        if url.isLRC, let text = SidecarParser.readText(url) {
            return SidecarParser.lyrics(lrc: text)
        }
        return []
    }

    /// Writes LRC or TTML, by the file's extension.
    static func write(_ lyrics: [Lyric], to url: URL) throws {
        let text = url.isTTML ? ttml(lyrics) : lrc(lyrics)
        try Data(text.utf8).write(to: url, options: .atomic)
    }

    /// LRC, or plain lines when nothing is timed, for an audio file's lyrics tag.
    static func tagText(_ lyrics: [Lyric]) -> String {
        guard lyrics.contains(where: { $0.start != 0 || $0.end != 0 }) else {
            return lyrics.map(\.content).joined(separator: "\n")
        }
        return lrc(lyrics)
    }

    /// LRC with `<mm:ss.xx>` word timing. A gap before the next line, and the end of the last,
    /// is marked by a timestamp without text.
    static func lrc(_ lyrics: [Lyric]) -> String {
        let lines = lyrics.sorted { $0.start < $1.start }
        var output: [String] = []
        var groupEnd: TimeInterval = 0
        for (index, line) in lines.enumerated() {
            var text = line.content
            if let segments = line.segments {
                text = segments.map { segment in
                    segment.phrase.map { "<\(timestamp($0.start))>\(segment.text)" } ?? String(segment.text)
                }.joined()
                if let last = line.phrases.last, last.end < line.end { text += "<\(timestamp(last.end))>" }
            }
            output.append("[\(timestamp(line.start))]\(text)")
            // Lines sharing a start, like a translation, end together after the last of them.
            groupEnd = index > 0 && lines[index - 1].start == line.start ? max(groupEnd, line.end) : line.end
            let next = index + 1 < lines.count ? lines[index + 1] : nil
            if let next, next.start == line.start { continue }
            if next.map({ $0.start - groupEnd >= 0.01 }) ?? true {
                output.append("[\(timestamp(groupEnd))]")
            }
        }
        return output.joined(separator: "\n") + "\n"
    }

    /// TTML with `<span>` word timing.
    static func ttml(_ lyrics: [Lyric]) -> String {
        let lines = lyrics.sorted { $0.start < $1.start }.map { line -> String in
            let text = line.segments.map { segments in
                segments.map { segment in
                    segment.phrase.map {
                        "<span begin=\"\(ttmlTime($0.start))\" end=\"\(ttmlTime($0.end))\">\(escaped(segment.text))</span>"
                    } ?? escaped(segment.text)
                }.joined()
            } ?? escaped(line.content)
            return "      <p begin=\"\(ttmlTime(line.start))\" end=\"\(ttmlTime(line.end))\">\(text)</p>"
        }
        return """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xmlns="http://www.w3.org/ns/ttml">
              <body>
                <div>
            \(lines.joined(separator: "\n"))
                </div>
              </body>
            </tt>

            """
    }

    /// `mm:ss.xx`
    static func timestamp(_ time: TimeInterval) -> String {
        let centiseconds = Int((max(0, time) * 100).rounded())
        return String(format: "%02d:%02d.%02d", centiseconds / 6000, centiseconds / 100 % 60, centiseconds % 100)
    }

    /// `mm:ss.xxx`, or `h:mm:ss.xxx` from an hour on.
    private static func ttmlTime(_ time: TimeInterval) -> String {
        let milliseconds = Int((max(0, time) * 1000).rounded())
        let hours = milliseconds / 3_600_000, minutes = milliseconds / 60_000 % 60
        let seconds = Double(milliseconds % 60_000) / 1000
        return hours > 0 ? String(format: "%d:%02d:%06.3f", hours, minutes, seconds)
                         : String(format: "%02d:%06.3f", minutes, seconds)
    }

    private static func escaped(_ text: some StringProtocol) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
    
}

extension Lyric {
    static public func examples() -> [Lyric] {
        return [
            Lyric(start: 31, end: 36, content: "只剩下鋼琴陪我談了一天", phrases: [
                Lyric(start: 31, end: 31.5, content: "只"),
                Lyric(start: 31.5, end: 32.5, content: "剩下"),
                Lyric(start: 32.5, end: 33.5, content: "鋼琴"),
                Lyric(start: 33.5, end: 34.5, content: "陪我"),
                Lyric(start: 34.5, end: 35, content: "談了"),
                Lyric(start: 35, end: 36, content: "一天"),
            ]),
            Lyric(start: 37, end: 43, content: "睡著的大提琴 安靜的舊舊的"),
            Lyric(start: 45, end: 49, content: "我想你已表現的非常明白"),
            Lyric(start: 50, end: 57, content: "我懂我也知道 你沒有捨不得"),
            
            Lyric(start: 58, end: 63, content: "你說你也會難過 我不相信"),
            Lyric(start: 64, end: 70, content: "牽著你 陪著我 也只是曾經"),
            Lyric(start: 71, end: 76, content: "希望他是真的比我還要愛你"),
            Lyric(start: 77, end: 82, content: "我才會逼自己離開"),
            
            Lyric(start: 83, end: 91, content: "你要我說多難堪 我根本不想分開"),
            Lyric(start: 92, end: 97, content: "為什麼還要我用微笑來帶過"),
            Lyric(start: 98, end: 103, content: "我沒有這種天份 包容你也接受他"),
            Lyric(start: 104, end: 110, content: "不用擔心的太多 我會一直好好過"),
            
            Lyric(start: 111, end: 117, content: "你已經遠遠離開 我也會慢慢走開"),
            Lyric(start: 118, end: 122, content: "為什麼我連分開都遷就著你"),
            Lyric(start: 123, end: 129, content: "我真的沒有天份 安靜的沒這麼快"),
            Lyric(start: 130, end: 135, content: "我會學著放棄你 是因為我太愛你"),
            
            
            Lyric(start: 151, end: 156, content: "只剩下鋼琴陪我談了一天"),
            Lyric(start: 157, end: 163, content: "睡著的大提琴 安靜的舊舊的"),
            Lyric(start: 164, end: 170, content: "我想你已表現的非常明白"),
            Lyric(start: 171, end: 176, content: "我懂我也知道 你沒有捨不得"),
            
            Lyric(start: 177, end: 183, content: "你說你也會難過 我不相信"),
            Lyric(start: 184, end: 189, content: "牽著你 陪著我 也只是曾經"),
            Lyric(start: 190, end: 196, content: "希望他是真的比我還要愛你"),
            Lyric(start: 197, end: 201, content: "我才會逼自己離開"),
            Lyric(start: 201.5, end: 204, content: "ooh~"),
            
            Lyric(start: 206, end: 211, content: "你要我說多難堪 我根本不想分開"),
            Lyric(start: 211.5, end: 217, content: "為什麼還要我用微笑來帶過"),
            Lyric(start: 218, end: 224, content: "我沒有這種天份 包容你也接受他"),
            Lyric(start: 225, end: 230, content: "不用擔心的太多 我會一直好好過"),

            Lyric(start: 231 , end: 237, content: "你已經遠遠離開 我也會慢慢走開"),
            Lyric(start: 238, end: 243, content: "為什麼我連分開都遷就著你"),
            Lyric(start: 244, end: 250, content: "我真的沒有天份 安靜的沒這麼快"),
            Lyric(start: 250.5, end: 254, content: "我會學著放棄你"),
            Lyric(start: 257.5, end: 260, content: "是因為我太愛你"),
        ]
    }
}
