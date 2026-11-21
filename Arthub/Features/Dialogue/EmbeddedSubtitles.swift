import AVFoundation

/// Reads only text samples; bitmap subtitle formats never enter the index.
enum EmbeddedSubtitles {
    static func read(_ url: URL) async throws -> [DialogueTrack] {
        if ["mkv", "webm"].contains(url.pathExtension.lowercased()) {
            return try MatroskaSubtitles.read(url)
        }
        let asset = AVURLAsset(url: url)
        let subtitleTracks = try await asset.loadTracks(withMediaType: .subtitle)
        let textTracks = try await asset.loadTracks(withMediaType: .text)
        let tracks = subtitleTracks + textTracks
        var result: [DialogueTrack] = []
        for track in tracks {
            try Task.checkCancellation()
            let formats = try await track.load(.formatDescriptions)
            guard let format = formats.first else { continue }
            let codec = CMFormatDescriptionGetMediaSubType(format)
            // tx3g, QuickTime text and WebVTT. Other codecs, including images, are skipped.
            guard [fourCC("tx3g"), fourCC("text"), fourCC("wvtt")].contains(codec) else { continue }
            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
            output.alwaysCopiesSampleData = false
            guard reader.canAdd(output) else { continue }
            defer { reader.cancelReading() }
            var cues: [SubtitleCue] = []
            func consume(_ sample: CMSampleBuffer) throws {
                try Task.checkCancellation()
                guard let buffer = CMSampleBufferGetDataBuffer(sample) else { return }
                let count = CMBlockBufferGetDataLength(buffer)
                guard count > 0 else { return }
                var data = Data(count: count)
                let status = data.withUnsafeMutableBytes { bytes in
                    CMBlockBufferCopyDataBytes(buffer, atOffset: 0, dataLength: count,
                                               destination: bytes.baseAddress!)
                }
                guard status == kCMBlockBufferNoErr, let text = text(data, codec: codec) else { return }
                let start = CMSampleBufferGetPresentationTimeStamp(sample).seconds
                let duration = CMSampleBufferGetDuration(sample).seconds
                guard start.isFinite, duration.isFinite, duration > 0 else { return }
                cues.append(SubtitleCue(start: start, end: start + duration, text: text))
            }
            if #available(macOS 26, iOS 26, tvOS 26, visionOS 26, *) {
                let provider = reader.outputProvider(for: output)
                try reader.start()
                while let sample = try await provider.next() {
                    try sample.withUnsafeSampleBuffer { try consume($0) }
                }
            } else {
                reader.add(output)
                guard reader.startReading() else { throw reader.error ?? CocoaError(.fileReadCorruptFile) }
                while let sample = output.copyNextSampleBuffer() { try consume(sample) }
            }
            if reader.status == .failed { throw reader.error ?? CocoaError(.fileReadCorruptFile) }
            let languageTag = try await track.load(.extendedLanguageTag)
            let languageCode = try await track.load(.languageCode)
            let language = languageTag ?? languageCode ?? ""
            result.append(DialogueTrack(id: "embedded:\(track.trackID)", name: language,
                                        cues: cues.sorted { $0.start < $1.start }))
        }
        return result
    }

    static func fourCC(_ string: String) -> FourCharCode {
        string.utf8.reduce(0) { ($0 << 8) | UInt32($1) }
    }

    static func text(_ data: Data, codec: FourCharCode) -> String? {
        let bytes = [UInt8](data)
        let payload: Data
        if codec == fourCC("wvtt") {
            return boxes(data, type: "vttc").flatMap { boxes($0, type: "payl") }
                .compactMap { String(data: $0, encoding: .utf8) }.map(clean)
                .filter { !$0.isEmpty }.joined(separator: "\n").nilIfEmpty
        } else {
            guard bytes.count >= 2 else { return nil }
            let length = Int(bytes[0]) << 8 | Int(bytes[1])
            guard length <= bytes.count - 2 else { return nil }
            payload = Data(bytes[2..<(2 + length)])
        }
        let encoding: String.Encoding = payload.starts(with: [0xFE, 0xFF]) || payload.starts(with: [0xFF, 0xFE]) ? .utf16 : .utf8
        return String(data: payload, encoding: encoding).map(clean)?.nilIfEmpty
    }

    private static func clean(_ text: String) -> String {
        text.replacing(/<[^>]+>/, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func boxes(_ data: Data, type: String) -> [Data] {
        let bytes = [UInt8](data)
        var offset = 0
        var result: [Data] = []
        while offset + 8 <= bytes.count {
            let size = bytes[offset..<(offset + 4)].reduce(0) { ($0 << 8) | Int($1) }
            guard size >= 8, size <= bytes.count - offset else { break }
            if String(bytes: bytes[(offset + 4)..<(offset + 8)], encoding: .ascii) == type {
                result.append(Data(bytes[(offset + 8)..<(offset + size)]))
            }
            offset += size
        }
        return result
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
