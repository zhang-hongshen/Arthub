import Foundation

/// Demuxes uncompressed Matroska text tracks without decoding video or audio.
/// Video packets and bitmap subtitle tracks are skipped by their EBML lengths.
enum MatroskaSubtitles {
    static func read(_ url: URL) throws -> [DialogueTrack] {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        return try data.withUnsafeBytes { bytes in
            try Parser(bytes: bytes).read()
        }
    }

    private struct Element {
        var id: UInt64
        var body: Range<Int>
    }

    private struct Track {
        var number: UInt64
        var codec: String
        var name: String
    }

    private struct Packet {
        var start: Double
        var duration: Double?
        var text: String
    }

    private final class Parser {
        let bytes: UnsafeRawBufferPointer
        var scale = 0.001 // Matroska's default timestamp tick is one millisecond.
        var tracks: [UInt64: Track] = [:]
        var packets: [UInt64: [Packet]] = [:]

        init(bytes: UnsafeRawBufferPointer) { self.bytes = bytes }

        func read() throws -> [DialogueTrack] {
            let roots = try elements(0..<bytes.count)
            guard roots.first?.id == 0x1A45DFA3,
                  let segment = roots.first(where: { $0.id == 0x18538067 }) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let children = try elements(segment.body)
            for child in children {
                if child.id == 0x1549A966 {
                    for value in try elements(child.body) where value.id == 0x2AD7B1 {
                        scale = Double(uint(value.body)) / 1_000_000_000
                    }
                } else if child.id == 0x1654AE6B {
                    for entry in try elements(child.body) where entry.id == 0xAE {
                        let fields = try elements(entry.body)
                        func value(_ id: UInt64) -> Element? { fields.first { $0.id == id } }
                        guard let number = value(0xD7), let codec = value(0x86),
                              value(0x6D80) == nil else { continue } // Compressed/encrypted tracks are excluded.
                        let codecName = string(codec.body)
                        guard ["S_TEXT/UTF8", "S_TEXT/ASS", "S_TEXT/SSA", "S_TEXT/WEBVTT"].contains(codecName) else { continue }
                        let name = value(0x536E).map { string($0.body) }
                            ?? value(0x22B59D).map { string($0.body) } ?? ""
                        let id = uint(number.body)
                        tracks[id] = Track(number: id, codec: codecName, name: name)
                    }
                }
            }
            guard scale.isFinite, scale > 0 else { throw CocoaError(.fileReadCorruptFile) }
            guard !tracks.isEmpty else { return [] }
            for cluster in children where cluster.id == 0x1F43B675 {
                try Task.checkCancellation()
                let blocks = try elements(cluster.body)
                let base = blocks.first { $0.id == 0xE7 }.map { Double(uint($0.body)) } ?? 0
                for block in blocks {
                    if block.id == 0xA3 { try packet(block.body, base: base, duration: nil) }
                    else if block.id == 0xA0 {
                        let group = try elements(block.body)
                        let duration = group.first { $0.id == 0x9B }.map { Double(uint($0.body)) * scale }
                        if let payload = group.first(where: { $0.id == 0xA1 }) {
                            try packet(payload.body, base: base, duration: duration)
                        }
                    }
                }
            }
            return tracks.values.sorted { $0.number < $1.number }.map { track in
                let lines = (packets[track.number] ?? []).sorted { $0.start < $1.start }
                let cues = lines.enumerated().map { offset, line in
                    let next = offset + 1 < lines.count ? lines[offset + 1].start : line.start + 5
                    return SubtitleCue(start: line.start, end: line.start + (line.duration ?? max(0.1, next - line.start)), text: line.text)
                }
                return DialogueTrack(id: "embedded:\(track.number)", name: track.name, cues: cues)
            }
        }

        func packet(_ range: Range<Int>, base: Double, duration: Double?) throws {
            var cursor = range.lowerBound
            let number = try vint(&cursor, end: range.upperBound, isID: false)
            guard let track = tracks[number], cursor + 3 <= range.upperBound else { return }
            let timestamp = Int16(bitPattern: UInt16(bytes[cursor]) << 8 | UInt16(bytes[cursor + 1]))
            let flags = bytes[cursor + 2]
            // Subtitle packets normally have no lacing. Never interpret laced/binary bytes as dialogue.
            guard flags & 0x06 == 0 else { return }
            cursor += 3
            var text = string(cursor..<range.upperBound)
            if track.codec == "S_TEXT/ASS" || track.codec == "S_TEXT/SSA" {
                let fields = text.split(separator: ",", maxSplits: 8, omittingEmptySubsequences: false)
                guard fields.count == 9 else { return }
                text = String(fields[8]).replacing(/\{[^}]*\}/, with: "")
                    .replacingOccurrences(of: "\\N", with: "\n")
                    .replacingOccurrences(of: "\\n", with: "\n")
                    .replacingOccurrences(of: "\\h", with: " ")
            }
            text = text.replacing(/<[^>]+>/, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            let start = (base + Double(timestamp)) * scale
            guard !text.isEmpty, start.isFinite, start >= 0 else { return }
            packets[number, default: []].append(Packet(start: start, duration: duration, text: text))
        }

        func elements(_ range: Range<Int>) throws -> [Element] {
            var cursor = range.lowerBound
            var result: [Element] = []
            while cursor < range.upperBound {
                try Task.checkCancellation()
                let id = try vint(&cursor, end: range.upperBound, isID: true)
                let sizeStart = cursor
                let size = try vint(&cursor, end: range.upperBound, isID: false)
                let bits = 7 * (cursor - sizeStart)
                let unknown = size == (UInt64(1) << bits) - 1
                guard unknown || size <= UInt64(range.upperBound - cursor) else { throw CocoaError(.fileReadCorruptFile) }
                let end = unknown ? range.upperBound : cursor + Int(size)
                result.append(Element(id: id, body: cursor..<end))
                cursor = end
            }
            return result
        }

        func vint(_ cursor: inout Int, end: Int, isID: Bool) throws -> UInt64 {
            guard cursor < end, bytes[cursor] != 0 else { throw CocoaError(.fileReadCorruptFile) }
            let first = bytes[cursor]
            let length = first.leadingZeroBitCount + 1
            guard length <= (isID ? 4 : 8), length <= end - cursor else { throw CocoaError(.fileReadCorruptFile) }
            var result = UInt64(isID ? first : first & (0xFF >> length))
            for offset in 1..<length { result = result << 8 | UInt64(bytes[cursor + offset]) }
            cursor += length
            return result
        }

        func uint(_ range: Range<Int>) -> UInt64 {
            guard range.count <= 8 else { return 0 }
            return range.reduce(0) { ($0 << 8) | UInt64(bytes[$1]) }
        }

        func string(_ range: Range<Int>) -> String {
            String(decoding: bytes[range], as: UTF8.self)
        }
    }
}
