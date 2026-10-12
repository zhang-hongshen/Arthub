//
//  SidecarParser.swift
//  Arthub
//

import Foundation

struct SubtitleCue: Equatable {
    var start: TimeInterval
    var end: TimeInterval
    var text: String
}

enum SidecarParser {

    /// Reads a text sidecar, trying UTF-8/UTF-16 before the legacy encodings common for Chinese subtitles.
    static func readText(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let legacy: [CFStringEncodings] = [.GB_18030_2000, .big5]
        let encodings: [String.Encoding] = [.utf8, .utf16] + legacy.map {
            String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding($0.rawValue)))
        } + [.windowsCP1252]
        for encoding in encodings {
            if encoding == .utf16, !(data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF])) { continue }
            if let text = String(data: data, encoding: encoding) {
                return text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\u{FEFF}"))
            }
        }
        return nil
    }

    // MARK: Subtitles

    /// SubRip (`.srt`), WebVTT (`.vtt`) and SubStation Alpha (`.ass`, `.ssa`).
    static func subtitles(url: URL) -> [SubtitleCue] {
        guard let text = readText(url) else { return [] }
        let cues = ["ass", "ssa"].contains(url.pathExtension.lowercased()) ? parseASS(text) : parseSRT(text)
        return cues.sorted { $0.start < $1.start }
    }

    /// SRT and WebVTT share the `start --> end` block layout.
    static func parseSRT(_ text: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        for block in text.components(separatedBy: "\n\n") {
            let lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            guard let index = lines.firstIndex(where: { $0.contains("-->") }) else { continue }
            let times = lines[index].components(separatedBy: "-->")
            guard times.count == 2, let start = timestamp(times[0]),
                  let end = timestamp(times[1].split(separator: " ", omittingEmptySubsequences: true).first.map(String.init) ?? "")
            else { continue }
            let content = lines[(index + 1)...].joined(separator: "\n")
                .replacing(/<[^>]+>|\{\\[^}]*\}/, with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty { cues.append(SubtitleCue(start: start, end: end, text: content)) }
        }
        return cues
    }

    static func parseASS(_ text: String) -> [SubtitleCue] {
        var fields = ["layer", "start", "end", "style", "name", "marginl", "marginr", "marginv", "effect", "text"]
        var cues: [SubtitleCue] = []
        for line in text.split(separator: "\n") {
            if line.hasPrefix("Format:") {
                fields = line.dropFirst(7).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                continue
            }
            guard line.hasPrefix("Dialogue:"),
                  let startIndex = fields.firstIndex(of: "start"), let endIndex = fields.firstIndex(of: "end"),
                  let textIndex = fields.firstIndex(of: "text") else { continue }
            let values = line.dropFirst(9).split(separator: ",", maxSplits: fields.count - 1,
                                                 omittingEmptySubsequences: false)
            guard values.count == fields.count, let start = timestamp(String(values[startIndex])),
                  let end = timestamp(String(values[endIndex])) else { continue }
            let content = String(values[textIndex])
                .replacing(/\{[^}]*\}/, with: "")
                .replacingOccurrences(of: "\\N", with: "\n").replacingOccurrences(of: "\\n", with: "\n")
                .replacingOccurrences(of: "\\h", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty { cues.append(SubtitleCue(start: start, end: end, text: content)) }
        }
        return cues
    }

    /// `01:02:03,456`, `02:03.456`, `0:02:03.45`
    static func timestamp(_ value: String) -> TimeInterval? {
        let parts = value.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
            .split(separator: ":")
        guard (2...3).contains(parts.count) else { return nil }
        var seconds: TimeInterval = 0
        for part in parts {
            guard let number = TimeInterval(part) else { return nil }
            seconds = seconds * 60 + number
        }
        return seconds
    }

    // MARK: Lyrics

    /// LRC lyrics, including several timestamps per line, `[offset:]` and `<mm:ss.xx>` word timing.
    /// Lines sharing a timestamp, like a translation under the original, are sung together;
    /// a timestamp without text only ends the line before it.
    static func lyrics(lrc text: String) -> [Lyric] {
        var offset: TimeInterval = 0
        var lines: [(start: TimeInterval, text: String)] = []
        for line in text.split(separator: "\n") {
            if let match = line.firstMatch(of: /(?i)^\[offset:\s*([+-]?\d+)\]/) {
                offset = (TimeInterval(match.output.1) ?? 0) / 1000
                continue
            }
            var rest = Substring(line)
            var starts: [TimeInterval] = []
            while let match = rest.prefixMatch(of: /\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]/) {
                starts.append(lrcTime(match.output.1, match.output.2, match.output.3))
                rest = rest[match.range.upperBound...]
            }
            lines += starts.map { (start: $0, text: String(rest)) }
        }
        // Stable, so a translation stays below its original.
        lines = lines.enumerated().sorted { ($0.element.start, $0.offset) < ($1.element.start, $1.offset) }.map { $0.element }
        // A positive offset shows lyrics earlier.
        return lines.indices.compactMap { index -> Lyric? in
            let line = lines[index]
            let start = max(0, line.start - offset)
            let next = lines[(index + 1)...].first { $0.start > line.start }
            let end = next.map { max(start, $0.start - offset) } ?? start + 10
            return lyric(start: start, end: end, text: line.text, offset: offset)
        }
    }

    /// `mm:ss`, `mm:ss.xx`, `mm:ss:xx` or `mm:ss.xxx`.
    private static func lrcTime(_ minutes: Substring, _ seconds: Substring, _ fraction: Substring?) -> TimeInterval {
        let fraction = fraction.flatMap { TimeInterval("0.\($0)") } ?? 0
        return (TimeInterval(minutes) ?? 0) * 60 + (TimeInterval(seconds) ?? 0) + fraction
    }

    /// `<mm:ss.xx>` tags time the words after them; text before the first tag starts with the line.
    private static func lyric(start: TimeInterval, end: TimeInterval, text: String, offset: TimeInterval) -> Lyric? {
        let tag = /<(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?>/
        let content = text.replacing(tag, with: "").trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return nil }
        let tags = text.matches(of: tag)
        guard let first = tags.first else { return Lyric(start: start, end: end, content: content) }
        var times = [start]
        var words = [text[..<first.range.lowerBound]]
        for (index, match) in tags.enumerated() {
            times.append(max(0, lrcTime(match.output.1, match.output.2, match.output.3) - offset))
            words.append(text[match.range.upperBound..<(index + 1 < tags.count ? tags[index + 1].range.lowerBound : text.endIndex)])
        }
        let phrases = words.indices.compactMap { index -> Lyric? in
            let word = words[index].trimmingCharacters(in: .whitespaces)
            guard !word.isEmpty else { return nil }
            return Lyric(start: times[index], end: index + 1 < times.count ? times[index + 1] : end, content: word)
        }
        return Lyric(start: start, end: end, content: content, phrases: phrases)
    }

    // MARK: Embedded Lyrics

    /// Lyrics kept as text in a tag (iTunes `©lyr`, ID3 `USLT`): TTML, LRC, or plain lines without timing.
    static func lyrics(text: String) -> [Lyric] {
        let text = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }
        if text.hasPrefix("<") {
            return TTMLParser().parse(data: Data(text.utf8))
        }
        let synced = lyrics(lrc: text)
        if !synced.isEmpty { return synced }
        return text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { Lyric(content: $0.trimmingCharacters(in: .whitespaces)) }
    }

    /// ID3 `SYLT` lyrics with millisecond timestamps. An entry beginning with a line break starts
    /// a new line, as does the entry after one ending with it; without any, each entry is a line.
    static func lyrics(sylt data: Data) -> [Lyric] {
        var bytes = [UInt8](data)
        // The frame may come with its 10-byte header.
        if bytes.starts(with: Array("SYLT".utf8)) { bytes.removeFirst(min(10, bytes.count)) }
        // Text encoding, language, timestamp format (2 is milliseconds), content type, then a descriptor.
        guard bytes.count > 6, bytes[0] <= 3, bytes[4] == 2 else { return [] }
        let encoding = bytes[0]
        let width = encoding == 1 || encoding == 2 ? 2 : 1
        var position = 6
        func readString() -> String? {
            var end = position
            while end + width <= bytes.count, bytes[end..<end + width].contains(where: { $0 != 0 }) { end += width }
            guard end + width <= bytes.count else { return nil }
            let data = Data(bytes[position..<end])
            position = end + width
            let text = switch encoding {
            case 0: String(data: data, encoding: .isoLatin1)
            case 1: String(data: data, encoding: data.starts(with: [0xFE, 0xFF]) || data.starts(with: [0xFF, 0xFE])
                           ? .utf16 : .utf16LittleEndian)
            case 2: String(data: data, encoding: .utf16BigEndian)
            default: String(data: data, encoding: .utf8)
            }
            return text?.trimmingCharacters(in: CharacterSet(charactersIn: "\u{FEFF}"))
        }
        guard readString() != nil else { return [] }
        var entries: [(start: TimeInterval, text: String)] = []
        while let text = readString(), position + 4 <= bytes.count {
            let milliseconds = bytes[position..<position + 4].reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
            entries.append((TimeInterval(milliseconds) / 1000, text))
            position += 4
        }
        let breaks = entries.contains { $0.text.first?.isNewline == true || $0.text.last?.isNewline == true }
        var lines: [[(start: TimeInterval, text: String)]] = []
        var lineEnded = true
        for entry in entries {
            if !breaks || lineEnded || entry.text.first?.isNewline == true { lines.append([]) }
            lineEnded = entry.text.last?.isNewline == true
            lines[lines.count - 1].append((entry.start, entry.text.trimmingCharacters(in: .newlines)))
        }
        return lines.indices.compactMap { index -> Lyric? in
            let words = lines[index]
            let start = words[0].start
            let end = index + 1 < lines.count ? max(start, lines[index + 1][0].start) : start + 10
            let content = words.map { $0.text }.joined().trimmingCharacters(in: .whitespaces)
            guard !content.isEmpty else { return nil }
            let phrases: [Lyric] = words.count < 2 ? [] : words.indices.compactMap { wordIndex -> Lyric? in
                let word = words[wordIndex]
                let text = word.text.trimmingCharacters(in: .whitespaces)
                guard !text.isEmpty else { return nil }
                let next = wordIndex + 1 < words.count ? words[wordIndex + 1].start : end
                return Lyric(start: word.start, end: next, content: text)
            }
            return Lyric(start: start, end: end, content: content, phrases: phrases)
        }
    }
}
