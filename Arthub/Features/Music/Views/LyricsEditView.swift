//
//  LyricsEditView.swift
//  Arthub
//
//  Created by 张鸿燊 on 5/2/2024.
//

import SwiftUI

struct LyricsEditView: View {
    
    @Bindable var song: Song
    @State private var sortOrders = [
        KeyPathComparator(\Lyric.start, order: .forward),
        KeyPathComparator(\Lyric.end, order: .forward)
    ]
    
    @State private var selectedLyrics: Set<Lyric.ID> =  Set()
    @State private var previewing: Bool = false
    @State private var previewTime: TimeInterval = 0
    @State private var fileExporterPresented: Bool = false
    @State private var fileImporterPresented: Bool = false
    @State private var timer: Timer?
    
    var body: some View {
        VStack(alignment: .leading) {
            
            ControlView()
            
            Table(of: Lyric.self, selection: $selectedLyrics, sortOrder: $sortOrders) {
                TableColumn("Start", value: \.start) { row in
                    Text(row.start.formatted())
                }
                TableColumn("End", value: \.end) { row in
                    Text(row.end.formatted())
                }
                TableColumn("Content", value: \.content) { row in
                    Text(row.content)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
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
            #if os(macOS)
            .alternatingRowBackgrounds()
            #endif
            .opacity(previewing ? 0 : 1)
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first, url.isTTML else {
                    return false
                }
                return importLyrics(url)
            }
            .overlay {
                LyricsPreview()
                    .opacity(previewing ? 1 : 0)
            }

            HStack {
                Button {
                    fileImporterPresented = true
                } label: {
                    Image(systemName: "plus")
                }
                Button {
                    deleteLyrics()
                } label: {
                    Image(systemName: "minus")
                }
            }
            .buttonStyle(.borderless)
        }
        #if os(macOS)
        .onDeleteCommand {
            deleteLyrics()
        }
        #endif
        .fileImporter(isPresented: $fileImporterPresented,
                      allowedContentTypes: [.ttml]) { result in
            switch result {
            case .success(let url):
                importLyrics(url)
                print("parse success")
            case .failure(let error):
                print("Failed to import document: \(error)")
            }
        }
        .task { fetchData() }
        .onChange(of: sortOrders, initial: true) { _,  newValue in
            song.lyrics.body.sort(using: newValue)
        }
    }
}


extension LyricsEditView {
    
    @ViewBuilder
    func ControlView() -> some View {
        HStack {
            Toggle("Preview", isOn: $previewing)
            
            Spacer()

        }
    }
    
    @ViewBuilder
    func LyricsPreview() -> some View {
        TimeSyncedLyricsView(lyrics: song.lyrics.body, syncedTime: $previewTime) { lyric in
            selectedLyrics = Set(arrayLiteral: lyric.id)
        }
        .onChange(of: previewing, initial: false) { oldValue, newValue in
            previewTime = 0
            if newValue {
                timer = Timer(timeInterval: 1, repeats: true) { timer in
                    previewTime += 1
                }
            } else {
                if let timer = self.timer {
                    timer.invalidate()
                    self.timer = nil
                }
            }
        }
        .onChange(of: previewTime, initial: false) { oldValue, newValue in
            if self.previewTime > (song.lyrics.body.last?.end ?? 0) {
                self.previewTime = 0
            }
        }
    }
}



extension LyricsEditView {
    
    func fetchData() {
        guard let url = song.lyrics.fileURL else {
            return
        }
        song.lyrics.body = Lyric.loadLyrics(url: url)
    }
    
    func deleteLyrics() {
        song.lyrics.body.removeAll{
            selectedLyrics.contains($0.id)
        }
    }
    
    func importLyrics(_ url: URL) -> Bool {
        do {
            var destURL: URL {
                guard let lyricsURL = song.lyrics.fileURL else {
                    return song.fileURL.deletingPathExtension().deletingLastPathComponent()
                        .appending(path: song.title, directoryHint: .notDirectory)
                        .appendingPathExtension(url.pathExtension)
                }
                return lyricsURL
            }
            song.lyrics.fileURL = try url.copy(to: destURL)
            song.lyrics.body = Lyric.loadLyrics(url: url)
        } catch {
            print("\(error)")
            return false
        }
        return true
    }
}
