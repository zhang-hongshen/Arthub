import Foundation
import CryptoKit
import Observation

struct DialogueTrack: Codable, Equatable {
    var id: String
    var name: String
    var cues: [SubtitleCue]
}

struct DialogueMatch: Identifiable {
    var id: String
    var fileID: UUID
    var source: String
    var cue: SubtitleCue
    var context: [SubtitleCue]
}

struct DialogueGroup: Identifiable {
    var id: String
    var file: LibraryFile
    var matches: [DialogueMatch]
}

@MainActor @Observable
final class DialogueSearch {
    static let shared = DialogueSearch()
    private(set) var isIndexing = false
    private(set) var revision = 0
    private(set) var error: String?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var pendingFiles: [LibraryFile]?
    private let index = DialogueIndex()

    /// Independent of metadata matching and the UI; never starts overlapping extraction passes.
    func refresh(_ files: [LibraryFile]) {
        pendingFiles = files
        guard task == nil else { return }
        isIndexing = true
        task = Task {
            while let snapshot = pendingFiles {
                pendingFiles = nil
                do {
                    try await index.refresh(snapshot)
                    error = nil
                } catch { self.error = error.localizedDescription }
                revision += 1
            }
            isIndexing = false
            task = nil
        }
    }

    func search(_ query: String, files: [LibraryFile]) async -> [DialogueGroup] {
        let matches = await index.search(query, fileIDs: Set(files.map(\.id)))
        let byID = Dictionary(uniqueKeysWithValues: files.map { ($0.id, $0) })
        var groups: [String: DialogueGroup] = [:]
        for match in matches {
            guard let file = byID[match.fileID] else { continue }
            let key = file.movie.map { "movie:\($0.id)" }
                ?? file.episode.map { "episode:\($0.id)" } ?? file.id.uuidString
            if groups[key] == nil { groups[key] = DialogueGroup(id: key, file: file, matches: []) }
            groups[key]?.matches.append(match)
        }
        return groups.values.sorted {
            $0.file.title.localizedStandardCompare($1.file.title) == .orderedAscending
        }
    }
}

/// Actor isolation keeps disk access, subtitle parsing and text matching off the UI thread.
actor DialogueIndex {
    private struct Source: Codable, Equatable {
        var fingerprint: String
        var tracks: [DialogueTrack]
    }
    private struct Entry: Codable, Equatable {
        var sources: [String: Source] = [:]
    }
    private var entries: [UUID: Entry] = [:]
    private var loaded = false
    private let url: URL

    init(url: URL = URL.appSupportDirectory.appending(path: "DialogueIndex-v1.json")) {
        self.url = url
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        // A derived cache can be rebuilt if missing or corrupt.
        if let data = try? Data(contentsOf: url),
           let saved = try? JSONDecoder().decode([UUID: Entry].self, from: data) { entries = saved }
    }

    func refresh(_ files: [LibraryFile]) async throws {
        load()
        let previous = entries
        let ids = Set(files.filter { $0.fileURL.isVideo }.map(\.id))
        entries = entries.filter { ids.contains($0.key) }
        var failure: Error?
        for file in files where file.isAvailable && file.fileURL.isVideo {
            try Task.checkCancellation()
            var entry = entries[file.id] ?? Entry()
            let subtitles = MediaNaming.subtitles(for: file.fileURL)
            let sourceIDs = Set(subtitles.map { $0.url.absoluteString }).union(["embedded"])
            entry.sources = entry.sources.filter { sourceIDs.contains($0.key) }
            for subtitle in subtitles {
                let key = subtitle.url.absoluteString
                do {
                    // Hash the small subtitle file, detecting even edits that preserve size and mtime.
                    let data = try Data(contentsOf: subtitle.url)
                    let fingerprint = SHA256.hash(data: data).description
                    if entry.sources[key]?.fingerprint != fingerprint {
                        let cues = SidecarParser.subtitles(url: subtitle.url).filter(Self.valid)
                        entry.sources[key] = Source(fingerprint: fingerprint,
                            tracks: [DialogueTrack(id: key, name: subtitle.displayName, cues: cues)])
                    }
                } catch {
                    entry.sources.removeValue(forKey: key)
                    failure = error
                }
            }
            do {
                let values = try file.fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                let fingerprint = "\(file.fileURL.absoluteString)|\(values.contentModificationDate?.timeIntervalSince1970 ?? 0)|\(values.fileSize ?? 0)"
                if entry.sources["embedded"]?.fingerprint != fingerprint {
                    // Drop stale text before awaiting extraction; a failed read is retried next scan.
                    entry.sources.removeValue(forKey: "embedded")
                    entries[file.id] = entry
                    let tracks = try await EmbeddedSubtitles.read(file.fileURL)
                    entry.sources["embedded"] = Source(fingerprint: fingerprint, tracks: tracks)
                }
            } catch {
                entry.sources.removeValue(forKey: "embedded")
                failure = error
            }
            entries[file.id] = entry
        }
        if entries != previous || !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(entries).write(to: url, options: .atomic)
        }
        if let failure { throw failure }
    }

    func search(_ query: String, fileIDs: Set<UUID>) -> [DialogueMatch] {
        load()
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        var result: [DialogueMatch] = []
        for id in fileIDs.sorted(by: { $0.uuidString < $1.uuidString }) {
            guard let entry = entries[id] else { continue }
            for key in entry.sources.keys.sorted() {
                for track in entry.sources[key]?.tracks ?? [] {
                    for (offset, cue) in track.cues.enumerated() where cue.text.localizedStandardContains(query) {
                        let context = Array(track.cues[max(0, offset - 2)..<min(track.cues.count, offset + 3)])
                        result.append(DialogueMatch(id: "\(id)/\(track.id)/\(offset)", fileID: id,
                                                    source: track.name, cue: cue, context: context))
                    }
                }
            }
        }
        return result.sorted { $0.cue.start < $1.cue.start }
    }

    private static func valid(_ cue: SubtitleCue) -> Bool {
        cue.start.isFinite && cue.end.isFinite && cue.start >= 0 && cue.end > cue.start && !cue.text.isEmpty
    }
}
