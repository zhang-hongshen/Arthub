//
//  LyricsEditView.swift
//  Arthub
//
//  Created by 张鸿燊 on 5/2/2024.
//

import SwiftUI
import UniformTypeIdentifiers

struct LyricsEditView: View {
    
    @Bindable var song: Song
    @State private var sortOrders = [
        KeyPathComparator(\Lyric.start, order: .forward),
        KeyPathComparator(\Lyric.end, order: .forward)
    ]
    
    @State private var selectedLyrics: Set<Lyric.ID> =  Set()
    @State private var previewing: Bool = false
    /// The song time the preview played from, and when.
    @State private var previewOrigin: TimeInterval = 0
    @State private var previewStartDate: Date = .now
    @State private var fileExporterPresented: Bool = false
    @State private var fileImporterPresented: Bool = false
    @State private var exportDocument: LyricsDocument?
    @State private var exportType: UTType = .lrc
    @State private var error: Error?
    
    var body: some View {
        VStack(alignment: .leading) {
            
            ControlView()
            
            Table(of: Lyric.self, selection: $selectedLyrics, sortOrder: $sortOrders) {
                TableColumn("Start", value: \.start) { row in
                    TextField("Start", value: binding(row, \.start), format: .lyricTime)
                }
                TableColumn("End", value: \.end) { row in
                    TextField("End", value: binding(row, \.end), format: .lyricTime)
                }
                TableColumn("Content", value: \.content) { row in
                    TextField("Content", text: binding(row, \.content))
                }
            } rows: {
                ForEach(song.lyrics.body) { lyric in
                    if lyric.phrases.isEmpty {
                        TableRow(lyric)
                    } else {
                        DisclosureTableRow(lyric) {
                            ForEach(lyric.phrases) { phrase in
                                TableRow(phrase)
                            }
                        }
                    }
                }
                .contextMenu {
                    Button("Delete", role: .destructive) {
                        deleteLyrics()
                    }
                }
            }
            .tableStyle(.inset)
            .textFieldStyle(.plain)
            #if os(macOS)
            .alternatingRowBackgrounds()
            #endif
            .opacity(previewing ? 0 : 1)
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first, url.isTTML || url.isLRC else {
                    return false
                }
                return importLyrics(url)
            }
            .overlay {
                if previewing {
                    LyricsPreview()
                }
            }

            HStack {
                Button(action: addLyric) {
                    Image(systemName: "plus")
                }
                Button(action: deleteLyrics) {
                    Image(systemName: "minus")
                }
                .disabled(selectedLyrics.isEmpty)
            }
            .buttonStyle(.borderless)
        }
        #if os(macOS)
        .onDeleteCommand {
            deleteLyrics()
        }
        #endif
        .fileImporter(isPresented: $fileImporterPresented,
                      allowedContentTypes: [.lrc, .ttml]) { result in
            switch result {
            case .success(let url):
                importLyrics(url)
            case .failure(let error):
                self.error = error
            }
        }
        .fileExporter(isPresented: $fileExporterPresented, document: exportDocument,
                      contentType: exportType, defaultFilename: song.fileURL.fileName) { result in
            if case .failure(let error) = result {
                self.error = error
            }
        }
        .alert(error: $error)
        .task(id: song.id) { fetchData() }
        .onChange(of: sortOrders, initial: true) { _,  newValue in
            song.lyrics.body.sort(using: newValue)
        }
        .onChange(of: previewing) { _, isOn in
            guard isOn else { return }
            // From the selected line, or just before the first one.
            let selected = song.lyrics.body.first { selectedLyrics.contains($0.id) }
            startPreview(from: selected?.start ?? max(0, (song.lyrics.body.map(\.start).min() ?? 0) - 1))
        }
    }
}


extension LyricsEditView {
    
    @ViewBuilder
    func ControlView() -> some View {
        HStack {
            Toggle("Preview", isOn: $previewing)
            
            Spacer()

            Button("Save") { saveLyrics() }
                .disabled(!song.lyrics.isUnsaved || song.isSaving)
                .help("Saves the lyrics into the song file.")

            Menu {
                Button("Import…") { fileImporterPresented = true }
                Menu("Export") {
                    Button { export(as: .lrc) } label: { Text(verbatim: "LRC…") }
                    Button { export(as: .ttml) } label: { Text(verbatim: "TTML…") }
                }
                .disabled(song.lyrics.body.isEmpty)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }
    
    @ViewBuilder
    func LyricsPreview() -> some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            TimeSyncedLyricsView(lyrics: song.lyrics.body, syncedTime: previewTime(at: context.date)) { lyric in
                selectedLyrics = [lyric.id]
                startPreview(from: lyric.start)
            }
        }
    }
}



extension LyricsEditView {
    
    func fetchData() {
        // Unsaved changes outlive switching tabs.
        guard !song.lyrics.isUnsaved, let url = song.lyrics.fileURL else {
            return
        }
        song.lyrics.body = Lyric.loadLyrics(url: url)
    }
    
    /// Changes stay unsaved until Save, so reloading the file doesn't discard them.
    func binding<Value>(_ lyric: Lyric, _ keyPath: ReferenceWritableKeyPath<Lyric, Value>) -> Binding<Value> {
        Binding(get: { lyric[keyPath: keyPath] },
                set: {
                    lyric[keyPath: keyPath] = $0
                    song.lyrics.isUnsaved = true
                })
    }

    /// A line after the selection, or at the end, starting where the line before it ends.
    func addLyric() {
        let body = song.lyrics.body
        let index = body.lastIndex { selectedLyrics.contains($0.id) }.map { $0 + 1 } ?? body.count
        let start = index > 0 ? body[index - 1].end : 0
        let lyric = Lyric(start: start, end: index < body.count ? max(start, body[index].start) : start + 5)
        song.lyrics.body.insert(lyric, at: index)
        selectedLyrics = [lyric.id]
        song.lyrics.isUnsaved = true
    }

    func deleteLyrics() {
        guard !selectedLyrics.isEmpty else { return }
        song.lyrics.body.removeAll { selectedLyrics.contains($0.id) }
        // A selected word loses its timing and stays in the line.
        for lyric in song.lyrics.body where lyric.phrases.contains(where: { selectedLyrics.contains($0.id) }) {
            lyric.phrases.removeAll { selectedLyrics.contains($0.id) }
        }
        selectedLyrics = []
        song.lyrics.isUnsaved = true
    }

    func saveLyrics() {
        Task {
            do {
                try await song.saveLyrics()
            } catch {
                self.error = error
            }
        }
    }
    
    /// Replaces the song's lyrics with the file's, and saves them like an edit.
    @discardableResult
    func importLyrics(_ url: URL) -> Bool {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let lyrics = Lyric.loadLyrics(url: url)
        guard !lyrics.isEmpty else { return false }
        song.lyrics.body = lyrics
        song.lyrics.isUnsaved = true
        saveLyrics()
        return true
    }

    func export(as type: UTType) {
        let body = song.lyrics.body
        exportDocument = LyricsDocument(text: type == .ttml ? Lyric.ttml(body) : Lyric.lrc(body))
        exportType = type
        fileExporterPresented = true
    }

    func startPreview(from time: TimeInterval) {
        previewOrigin = time
        previewStartDate = .now
    }

    /// Loops from just before the first line to the end of the last.
    func previewTime(at date: Date) -> TimeInterval {
        let body = song.lyrics.body
        let first = max(0, (body.map(\.start).min() ?? 0) - 1)
        let length = max((body.map(\.end).max() ?? 0) - first, 1)
        let elapsed = previewOrigin - first + date.timeIntervalSince(previewStartDate)
        return first + elapsed.truncatingRemainder(dividingBy: length)
    }
}

/// Lyrics text for the file exporter.
fileprivate struct LyricsDocument: FileDocument {

    static var readableContentTypes: [UTType] { [.lrc, .ttml] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

/// `mm:ss.xx` lyric times; plain seconds are accepted too.
fileprivate struct LyricTimeFormat: ParseableFormatStyle {

    var parseStrategy: Strategy { Strategy() }

    func format(_ value: TimeInterval) -> String {
        Lyric.timestamp(value)
    }

    struct Strategy: ParseStrategy {
        func parse(_ value: String) throws -> TimeInterval {
            guard let time = SidecarParser.timestamp(value) ?? TimeInterval(value.trimmingCharacters(in: .whitespaces)),
                  time >= 0 else {
                throw CocoaError(.formatting)
            }
            return time
        }
    }
}

fileprivate extension ParseableFormatStyle where Self == LyricTimeFormat {
    static var lyricTime: LyricTimeFormat { LyricTimeFormat() }
}
