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
    static func lyrics(lrc text: String) -> [Lyric] {
        var offset: TimeInterval = 0
        var lines: [(TimeInterval, String)] = []
        for line in text.split(separator: "\n") {
            if let match = line.firstMatch(of: /(?i)^\[offset:\s*([+-]?\d+)\]/) {
                offset = (TimeInterval(match.output.1) ?? 0) / 1000
                continue
            }
            var rest = Substring(line)
            var starts: [TimeInterval] = []
            while let match = rest.prefixMatch(of: /\[(\d{1,3}:\d{1,2}(?:[.:]\d{1,3})?)\]/) {
                if let start = timestamp(String(match.output.1).replacing(/:(\d{1,3})$/, with: { ".\($0.output.1)" })) {
                    starts.append(start)
                }
                rest = rest[match.range.upperBound...]
            }
            lines += starts.map { ($0, String(rest)) }
        }
        lines.sort { $0.0 < $1.0 }
        // A positive offset shows lyrics earlier.
        return lines.enumerated().map { index, line in
            let start = max(0, line.0 - offset)
            let end = index + 1 < lines.count ? max(start, lines[index + 1].0 - offset) : start + 10
            return lyric(start: start, end: end, text: line.1, offset: offset)
        }
    }

    private static func lyric(start: TimeInterval, end: TimeInterval, text: String, offset: TimeInterval) -> Lyric {
        let words = text.matches(of: /<(\d{1,3}:\d{1,2}(?:\.\d{1,3})?)>([^<]*)/)
        guard !words.isEmpty else {
            return Lyric(start: start, end: end, content: text.trimmingCharacters(in: .whitespaces))
        }
        let times = words.map { timestamp(String($0.output.1)).map { max(0, $0 - offset) } ?? start }
        let phrases = words.enumerated().compactMap { index, word -> Lyric? in
            let content = String(word.output.2)
            guard !content.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            return Lyric(start: times[index], end: index + 1 < times.count ? times[index + 1] : end, content: content)
        }
        return Lyric(start: start, end: end, content: phrases.map(\.content).joined().trimmingCharacters(in: .whitespaces),
                     phrases: phrases)
    }
}
