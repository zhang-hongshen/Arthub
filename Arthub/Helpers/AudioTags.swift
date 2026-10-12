//
//  AudioTags.swift
//  Arthub
//

import Foundation
import AVFoundation
import CoreMedia

/// A tag written into the audio file itself. An empty value removes it.
enum AudioTag {
    case title(String), artist(String), album(String), albumArtist(String)
    case composer(String), lyricist(String), arranger(String)
    case trackNumber(Int?), discNumber(Int?)
    case cover(Data?)
    /// LRC, or plain lines without timing.
    case lyrics(String)
}

/// Tags inside the audio file: ID3v2 in MP3, iTunes atoms in M4A and Vorbis comments in FLAC.
enum AudioTags {

    static func canWrite(_ url: URL) -> Bool {
        ["mp3", "m4a", "flac"].contains(url.pathExtension.lowercased())
    }

    /// Rewrites the file with the tags changed. Other tags and the audio stay as they are.
    static func write(_ tags: [AudioTag], to url: URL) async throws {
        guard !tags.isEmpty else { return }
        let format = url.pathExtension.lowercased()
        guard canWrite(url) else { throw AudioTagError.unsupportedFormat }
        let directory = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                                    appropriateFor: url, create: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let temporary = directory.appending(path: url.lastPathComponent)
        if format == "m4a" {
            try await MP4.export(url, with: tags, to: temporary)
        } else {
            let data = try Data(contentsOf: url, options: .alwaysMapped)
            let (head, audioStart) = try format == "mp3" ? ID3.head(of: data, with: tags) : FLAC.head(of: data, with: tags)
            try write(head, then: url, from: audioStart, to: temporary)
        }
        // Unlike writing over it, this keeps the original's permissions and other attributes.
        _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary)
    }

    /// Vorbis comments by upper-cased name, and the front cover. AVFoundation doesn't read either from FLAC.
    static func readFLAC(_ url: URL) -> (comments: [String: String], cover: Data?)? {
        guard url.pathExtension.lowercased() == "flac",
              let data = try? Data(contentsOf: url, options: .alwaysMapped),
              let file = try? FLAC.parse(data) else { return nil }
        var comments: [String: String] = [:]
        for block in file.blocks where block.type == FLAC.commentType {
            for comment in FLAC.comments(in: block.data).comments {
                let name = FLAC.name(of: comment)
                if comments[name] == nil { comments[name] = FLAC.value(of: comment) }
            }
        }
        let pictures = file.blocks.filter { $0.type == FLAC.pictureType }.compactMap { FLAC.picture(in: $0.data) }
        return (comments, (pictures.first { $0.type == 3 } ?? pictures.first)?.image)
    }

    /// `3` from `3/12`.
    static func number(in text: String) -> Int? {
        text.prefixMatch(of: /\s*(\d+)/).flatMap { Int($0.output.1) }
    }

    /// `2003`, `2003-07` or `2003-07-31`, ignoring a time after it.
    static func date(in text: String) -> Date? {
        guard let match = text.prefixMatch(of: /\s*(\d{4})(?:-(\d{2})(?:-(\d{2}))?)?/) else { return nil }
        return DateComponents(calendar: .current, year: Int(match.output.1),
                              month: match.output.2.flatMap { Int($0) }, day: match.output.3.flatMap { Int($0) }).date
    }

    fileprivate static func mimeType(_ image: Data) -> String {
        image.starts(with: [0x89, 0x50, 0x4E, 0x47]) ? "image/png" : "image/jpeg"
    }

    /// The new head, then the original file from `offset` on, copied in pieces to spare memory.
    private static func write(_ head: Data, then url: URL, from offset: Int, to destination: URL) throws {
        guard FileManager.default.createFile(atPath: destination.path, contents: head) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let output = try FileHandle(forWritingTo: destination)
        defer { try? output.close() }
        let input = try FileHandle(forReadingFrom: url)
        defer { try? input.close() }
        _ = try output.seekToEnd()
        try input.seek(toOffset: UInt64(offset))
        while let chunk = try input.read(upToCount: 1 << 20), !chunk.isEmpty {
            try output.write(contentsOf: chunk)
        }
    }
}

enum AudioTagError: LocalizedError {
    case unsupportedFormat, unsupportedTag, invalidFile, tooLarge

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat: String(localized: "Tags can only be written into MP3, M4A and FLAC files.")
        case .unsupportedTag: String(localized: "This file's tags are in an older version that can't be written.")
        case .invalidFile: String(localized: "This file couldn't be read as audio.")
        case .tooLarge: String(localized: "The artwork is too large to write into this file.")
        }
    }
}

extension AVMetadataItem {

    /// A number, also from text such as ID3's `3/12`, or M4A's binary `trkn` and `disk` atoms.
    func loadNumber() async throws -> Int? {
        if let number = try await load(.numberValue) { return number.intValue }
        if let text = try await load(.stringValue) { return AudioTags.number(in: text) }
        // Two reserved bytes, then the number in two big-endian bytes.
        guard let data = try await load(.dataValue), data.count >= 4 else { return nil }
        return data.dropFirst(2).prefix(2).integer()
    }

    /// A date, also from text such as ID3's `2003` or `2003-07-31`.
    func loadDate() async throws -> Date? {
        if let date = try await load(.dateValue) { return date }
        return try await load(.stringValue).flatMap(AudioTags.date(in:))
    }
}

// MARK: ID3

/// ID3v2.3 and v2.4 tags at the start of an MP3. Frames that aren't written are kept as they are.
private enum ID3 {

    struct Frame {
        var id: String
        var flags: [UInt8] = [0, 0]
        var body: Data
    }

    /// The new tag, and where the audio after the old one starts.
    static func head(of data: Data, with tags: [AudioTag]) throws -> (Data, Int) {
        var version: UInt8 = 3
        var frames: [Frame] = []
        var audioStart = 0
        if data.count >= 10, data.starts(with: Array("ID3".utf8)) {
            version = data[3]
            let flags = data[5]
            // ID3v2.2 names frames with three letters, and an unsynchronised tag hides its frames.
            guard version == 3 || version == 4, flags & 0x80 == 0 else { throw AudioTagError.unsupportedTag }
            let size = data[6..<10].integer(synchsafe: true)
            guard 10 + size <= data.count else { throw AudioTagError.invalidFile }
            audioStart = 10 + size + (flags & 0x10 != 0 ? 10 : 0)
            frames = parseFrames(Data(data[10..<10 + size]), version: version, extendedHeader: flags & 0x40 != 0)
        }
        for tag in tags { apply(tag, to: &frames) }
        var body = Data()
        for frame in frames {
            body.append(contentsOf: Array(frame.id.utf8))
            body.append(contentsOf: bytes(frame.body.count, count: 4, synchsafe: version == 4))
            body.append(contentsOf: frame.flags)
            body.append(frame.body)
        }
        // Padding lets other taggers edit in place later.
        body.append(Data(count: 2048))
        var head = Data("ID3".utf8)
        head.append(contentsOf: [version, 0, 0])
        head.append(contentsOf: bytes(body.count, count: 4, synchsafe: true))
        head.append(body)
        return (head, audioStart)
    }

    private static func parseFrames(_ tag: Data, version: UInt8, extendedHeader: Bool) -> [Frame] {
        var position = 0
        if extendedHeader, tag.count >= 4 {
            // Its size counts itself in v2.4, but not in v2.3.
            position = version == 4 ? tag[0..<4].integer(synchsafe: true) : tag[0..<4].integer() + 4
        }
        var frames: [Frame] = []
        // Padding starts with a zero byte.
        while position + 10 <= tag.count, tag[position] != 0 {
            let end = position + 10 + tag[position + 4..<position + 8].integer(synchsafe: version == 4)
            guard end <= tag.count else { break }
            frames.append(Frame(id: String(decoding: tag[position..<position + 4], as: UTF8.self),
                                flags: Array(tag[position + 8..<position + 10]),
                                body: Data(tag[position + 10..<end])))
            position = end
        }
        return frames
    }

    private static func apply(_ tag: AudioTag, to frames: inout [Frame]) {
        switch tag {
        case .title(let value): setText("TIT2", value, in: &frames)
        case .artist(let value): setText("TPE1", value, in: &frames)
        case .album(let value): setText("TALB", value, in: &frames)
        case .albumArtist(let value): setText("TPE2", value, in: &frames)
        case .composer(let value): setText("TCOM", value, in: &frames)
        case .lyricist(let value): setText("TEXT", value, in: &frames)
        // ID3 has no frame for the arranger.
        case .arranger: break
        case .trackNumber(let value): setNumber("TRCK", value, in: &frames)
        case .discNumber(let value): setNumber("TPOS", value, in: &frames)
        case .cover(let image):
            // Replaces the front cover and untyped pictures; others, like the back cover, stay.
            frames.removeAll { $0.id == "APIC" && isCover($0.body) }
            guard let image else { return }
            var body = Data([0])
            body.append(Data(AudioTags.mimeType(image).utf8))
            // The MIME type's terminator, front cover, and an empty description.
            body.append(contentsOf: [0, 3, 0])
            body.append(image)
            // The first picture is read as the cover.
            frames.insert(Frame(id: "APIC", body: body), at: frames.firstIndex { $0.id == "APIC" } ?? frames.endIndex)
        case .lyrics(let text):
            // Timed SYLT lyrics are read before USLT, so they go as well.
            frames.removeAll { $0.id == "USLT" || $0.id == "SYLT" }
            guard !text.isEmpty else { return }
            var body = Data([1])
            body.append(Data("und".utf8))
            // An empty description: byte order mark and terminator.
            body.append(contentsOf: [0xFF, 0xFE, 0, 0])
            body.append(utf16(text))
            frames.append(Frame(id: "USLT", body: body))
        }
    }

    private static func setText(_ id: String, _ value: String, in frames: inout [Frame]) {
        frames.removeAll { $0.id == id }
        guard !value.isEmpty else { return }
        frames.append(Frame(id: id, body: Data([1]) + utf16(value)))
    }

    /// A total such as `3/12` is kept while the number stays the same.
    private static func setNumber(_ id: String, _ value: Int?, in frames: inout [Frame]) {
        if let value, let frame = frames.first(where: { $0.id == id }),
           text(frame.body).flatMap(AudioTags.number(in:)) == value { return }
        setText(id, value.map(String.init) ?? "", in: &frames)
    }

    /// UTF-16 with a byte order mark, which both v2.3 and v2.4 read.
    private static func utf16(_ text: String) -> Data {
        var data = Data([0xFF, 0xFE])
        for unit in text.utf16 { data.append(contentsOf: [UInt8(unit & 0xFF), UInt8(unit >> 8)]) }
        return data
    }

    private static func text(_ body: Data) -> String? {
        guard let encoding = body.first else { return nil }
        let content = body.dropFirst()
        let text = switch encoding {
        case 0: String(data: content, encoding: .isoLatin1)
        case 1: String(data: content, encoding: .utf16)
        case 2: String(data: content, encoding: .utf16BigEndian)
        default: String(data: content, encoding: .utf8)
        }
        return text?.trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
    }

    /// An APIC frame of the front cover (3) or an untyped picture (0).
    private static func isCover(_ body: Data) -> Bool {
        // Text encoding, the MIME type ending in a zero byte, then the picture type.
        guard let end = body.dropFirst().firstIndex(of: 0), end + 1 < body.endIndex else { return false }
        return [0, 3].contains(body[end + 1])
    }
}

// MARK: FLAC

/// Metadata blocks at the start of a FLAC file. Blocks other than comments, covers and padding are kept.
private enum FLAC {

    static let paddingType: UInt8 = 1
    static let commentType: UInt8 = 4
    static let pictureType: UInt8 = 6

    struct Block {
        var type: UInt8
        var data: Data
    }

    /// Anything before `fLaC` such as a stray ID3 tag, the blocks, and where the audio starts.
    static func parse(_ data: Data) throws -> (prefix: Data, blocks: [Block], audioStart: Int) {
        var start = 0
        if data.count >= 10, data.starts(with: Array("ID3".utf8)) {
            start = 10 + data[6..<10].integer(synchsafe: true) + (data[5] & 0x10 != 0 ? 10 : 0)
        }
        guard start + 4 <= data.count, data[start..<start + 4].elementsEqual("fLaC".utf8) else {
            throw AudioTagError.invalidFile
        }
        var position = start + 4
        var blocks: [Block] = []
        var isLast = false
        while !isLast {
            guard position + 4 <= data.count else { throw AudioTagError.invalidFile }
            isLast = data[position] & 0x80 != 0
            let end = position + 4 + data[position + 1..<position + 4].integer()
            guard end <= data.count else { throw AudioTagError.invalidFile }
            blocks.append(Block(type: data[position] & 0x7F, data: data.subdata(in: position + 4..<end)))
            position = end
        }
        return (data.subdata(in: 0..<start), blocks, position)
    }

    /// The new metadata, and where the audio starts.
    static func head(of data: Data, with tags: [AudioTag]) throws -> (Data, Int) {
        let file = try parse(data)
        var blocks = file.blocks.filter { $0.type != paddingType }
        let old = blocks.first { $0.type == commentType }.map { FLAC.comments(in: $0.data) }
        var comments = old?.comments ?? []
        for tag in tags {
            switch tag {
            case .title(let value): set("TITLE", value, in: &comments)
            case .artist(let value): set("ARTIST", value, in: &comments)
            case .album(let value): set("ALBUM", value, in: &comments)
            case .albumArtist(let value): set("ALBUMARTIST", value, replacing: ["ALBUM ARTIST"], in: &comments)
            case .composer(let value): set("COMPOSER", value, in: &comments)
            case .lyricist(let value): set("LYRICIST", value, in: &comments)
            case .arranger(let value): set("ARRANGER", value, in: &comments)
            case .trackNumber(let value): setNumber("TRACKNUMBER", value, in: &comments)
            case .discNumber(let value): setNumber("DISCNUMBER", value, in: &comments)
            case .lyrics(let text): set("LYRICS", text, replacing: ["UNSYNCEDLYRICS"], in: &comments)
            case .cover(let image):
                // Replaces the front cover and untyped pictures; others, like the back cover, stay.
                blocks.removeAll { block in
                    guard block.type == pictureType, let type = picture(in: block.data)?.type else { return false }
                    return type == 0 || type == 3
                }
                if let image { blocks.append(Block(type: pictureType, data: pictureData(image))) }
            }
        }
        let commentBlock = Block(type: commentType,
                                 data: commentData(vendor: old?.vendor ?? Data("Arthub".utf8), comments: comments))
        if let index = blocks.firstIndex(where: { $0.type == commentType }) {
            blocks[index] = commentBlock
        } else {
            // Stream info stays first.
            blocks.insert(commentBlock, at: min(1, blocks.count))
        }
        // Padding lets other taggers edit in place later.
        blocks.append(Block(type: paddingType, data: Data(count: 4096)))
        var head = file.prefix
        head.append(Data("fLaC".utf8))
        for (index, block) in blocks.enumerated() {
            guard block.data.count < 1 << 24 else { throw AudioTagError.tooLarge }
            head.append((index == blocks.count - 1 ? 0x80 : 0) | block.type)
            head.append(contentsOf: bytes(block.data.count, count: 3))
            head.append(block.data)
        }
        return (head, file.audioStart)
    }

    /// The name before `=`, which is matched without case.
    static func name(of comment: String) -> String {
        String(comment.prefix { $0 != "=" }).uppercased()
    }

    static func value(of comment: String) -> String {
        String(comment.drop { $0 != "=" }.dropFirst())
    }

    private static func set(_ name: String, _ value: String, replacing aliases: [String] = [],
                            in comments: inout [String]) {
        let names = Set([name] + aliases)
        comments.removeAll { names.contains(self.name(of: $0)) }
        if !value.isEmpty { comments.append("\(name)=\(value)") }
    }

    /// A total such as `3/12` is kept while the number stays the same.
    private static func setNumber(_ name: String, _ value: Int?, in comments: inout [String]) {
        if let value, let comment = comments.first(where: { self.name(of: $0) == name }),
           AudioTags.number(in: self.value(of: comment)) == value { return }
        set(name, value.map(String.init) ?? "", in: &comments)
    }

    /// Lengths are little-endian here, unlike the rest of FLAC.
    static func comments(in block: Data) -> (vendor: Data, comments: [String]) {
        var reader = ByteReader(block)
        guard let vendorLength = reader.integer(littleEndian: true), let vendor = reader.read(vendorLength),
              let count = reader.integer(littleEndian: true) else { return (Data(), []) }
        var comments: [String] = []
        for _ in 0..<count {
            guard let length = reader.integer(littleEndian: true), let comment = reader.read(length) else { break }
            comments.append(String(decoding: comment, as: UTF8.self))
        }
        return (vendor, comments)
    }

    private static func commentData(vendor: Data, comments: [String]) -> Data {
        var data = Data(bytes(vendor.count, count: 4, littleEndian: true))
        data.append(vendor)
        data.append(contentsOf: bytes(comments.count, count: 4, littleEndian: true))
        for comment in comments {
            let text = Data(comment.utf8)
            data.append(contentsOf: bytes(text.count, count: 4, littleEndian: true))
            data.append(text)
        }
        return data
    }

    static func picture(in block: Data) -> (type: Int, image: Data)? {
        var reader = ByteReader(block)
        guard let type = reader.integer(),
              let mimeLength = reader.integer(), reader.read(mimeLength) != nil,
              let descriptionLength = reader.integer(), reader.read(descriptionLength) != nil,
              // Width, height, color depth and palette size.
              reader.read(16) != nil,
              let length = reader.integer(), let image = reader.read(length) else { return nil }
        return (type, image)
    }

    private static func pictureData(_ image: Data) -> Data {
        let mimeType = Data(AudioTags.mimeType(image).utf8)
        // Front cover.
        var data = Data(bytes(3, count: 4))
        data.append(contentsOf: bytes(mimeType.count, count: 4))
        data.append(mimeType)
        // No description, and the image's size and colors left unstated.
        data.append(Data(count: 20))
        data.append(contentsOf: bytes(image.count, count: 4))
        data.append(image)
        return data
    }
}

// MARK: MP4

/// iTunes atoms in an M4A file, rewritten by a passthrough export that copies the audio untouched.
private enum MP4 {

    static func export(_ url: URL, with tags: [AudioTag], to destination: URL) async throws {
        let asset = AVURLAsset(url: url)
        var items = try await asset.load(.metadata)
        for tag in tags {
            // There's no standard atom for the lyricist.
            guard let change = atom(for: tag) else { continue }
            let (identifier, item) = change
            switch tag {
            case .trackNumber(let number?), .discNumber(let number?):
                // Keeps a total, such as 3 of 12, while the number stays the same.
                if let existing = items.first(where: { $0.identifier == identifier }),
                   try await existing.loadNumber() == number { continue }
            default: break
            }
            items.removeAll { $0.identifier == identifier }
            if let item { items.append(item) }
        }
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw AudioTagError.invalidFile
        }
        session.metadata = items
        if #available(macOS 15, iOS 18, tvOS 18, *) {
            try await session.export(to: destination, as: .m4a)
        } else {
            session.outputURL = destination
            session.outputFileType = .m4a
            await session.export()
            if session.status != .completed { throw session.error ?? AudioTagError.invalidFile }
        }
    }

    /// The atom a tag goes in, and its new item, nil to remove it.
    private static func atom(for tag: AudioTag) -> (AVMetadataIdentifier, AVMetadataItem?)? {
        switch tag {
        case .title(let text): textAtom(.iTunesMetadataSongName, text)
        case .artist(let text): textAtom(.iTunesMetadataArtist, text)
        case .album(let text): textAtom(.iTunesMetadataAlbum, text)
        case .albumArtist(let text): textAtom(.iTunesMetadataAlbumArtist, text)
        case .composer(let text): textAtom(.iTunesMetadataComposer, text)
        case .arranger(let text): textAtom(.iTunesMetadataArranger, text)
        case .lyrics(let text): textAtom(.iTunesMetadataLyrics, text)
        case .lyricist: nil
        // Two reserved bytes, the number, the total (unknown) and, for tracks, two more reserved bytes.
        case .trackNumber(let number):
            (.iTunesMetadataTrackNumber, number.map {
                item(.iTunesMetadataTrackNumber, Data([0, 0] + bytes($0, count: 2) + [0, 0, 0, 0]) as NSData,
                     type: kCMMetadataBaseDataType_RawData)
            })
        case .discNumber(let number):
            (.iTunesMetadataDiscNumber, number.map {
                item(.iTunesMetadataDiscNumber, Data([0, 0] + bytes($0, count: 2) + [0, 0]) as NSData,
                     type: kCMMetadataBaseDataType_RawData)
            })
        case .cover(let image):
            (.iTunesMetadataCoverArt, image.map {
                item(.iTunesMetadataCoverArt, $0 as NSData, type: AudioTags.mimeType($0) == "image/png"
                     ? kCMMetadataBaseDataType_PNG : kCMMetadataBaseDataType_JPEG)
            })
        }
    }

    private static func textAtom(_ identifier: AVMetadataIdentifier, _ text: String) -> (AVMetadataIdentifier, AVMetadataItem?) {
        (identifier, text.isEmpty ? nil : item(identifier, text as NSString, type: kCMMetadataBaseDataType_UTF8))
    }

    private static func item(_ identifier: AVMetadataIdentifier, _ value: NSCopying & NSObjectProtocol,
                             type: CFString) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = value
        item.dataType = type as String
        return item
    }
}

// MARK: Bytes

/// Reads a block's fields in order, failing past its end.
private struct ByteReader {
    let data: Data
    var position: Int

    init(_ data: Data) {
        self.data = data
        position = data.startIndex
    }

    mutating func read(_ count: Int) -> Data? {
        guard count >= 0, position + count <= data.endIndex else { return nil }
        defer { position += count }
        return Data(data[position..<position + count])
    }

    /// Four bytes, big-endian unless said otherwise.
    mutating func integer(littleEndian: Bool = false) -> Int? {
        guard let bytes = read(4) else { return nil }
        return (littleEndian ? Array(bytes.reversed()) : Array(bytes)).integer()
    }
}

fileprivate extension Collection where Element == UInt8 {
    /// Big-endian, or synchsafe with seven bits a byte like ID3 sizes.
    func integer(synchsafe: Bool = false) -> Int {
        reduce(0) { synchsafe ? $0 << 7 | Int($1 & 0x7F) : $0 << 8 | Int($1) }
    }
}

/// `value` in `count` bytes, big-endian unless said otherwise.
private func bytes(_ value: Int, count: Int, synchsafe: Bool = false, littleEndian: Bool = false) -> [UInt8] {
    let bigEndian = (0..<count).reversed().map { index in
        synchsafe ? UInt8(value >> (index * 7) & 0x7F) : UInt8(truncatingIfNeeded: value >> (index * 8))
    }
    return littleEndian ? Array(bigEndian.reversed()) : bigEndian
}
