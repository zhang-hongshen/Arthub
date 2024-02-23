//
//  LyricsEditView.swift
//  Arthub
//
//  Created by 张鸿燊 on 5/2/2024.
//

import SwiftUI

struct LyricsEditView: View {
    @Binding var lyrics: [Lyric]
    @State private var sortOrders = [
        KeyPathComparator(\Lyric.start, order: .forward),
        KeyPathComparator(\Lyric.end, order: .forward)
    ]
    
    @State private var selectedLyrics: Set<Lyric.ID> =  Set()
    @State private var previewing: Bool = false
    @State private var fileExporterPresented: Bool = false
    @State private var fileImporterPresented: Bool = false
    @State private var previewTime: TimeInterval = 0
    @State private var timer: Timer?
    
    var body: some View {
        VStack(alignment: .leading) {
            
            ControlView()
            
            Table(of: Lyric.self, selection: $selectedLyrics, sortOrder: $sortOrders) {
                TableColumn("lyric.start", value: \.start) { row in
                    Text(row.start.formatted())
                }
                TableColumn("lyric.end", value: \.end) { row in
                    Text(row.end.formatted())
                }
                TableColumn("lyric.content", value: \.content) { row in
                    Text(row.content)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } rows: {
                ForEach(lyrics) { lyric in
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
                    Button("common.delete", role: .destructive) {
                        deleteLyrics()
                    }
                }
            }
            .tableStyle(.inset)
            .alternatingRowBackgrounds()
            .opacity(previewing ? 0 : 1)
            .overlay {
                previewView()
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
        .onDeleteCommand {
            deleteLyrics()
        }
        .onChange(of: sortOrders, initial: true) { _,  newValue in
            self.lyrics.sort(using: newValue)
        }
        .fileImporter(isPresented: $fileImporterPresented, 
                      allowedContentTypes: [.ttml]) { result in
            switch result {
            case .success(let url):
                lyrics = TTMLParser.shared.parse(url: url)
                print("parse success")
            case .failure(let error):
                print("Failed to import document: \(error)")
            }
        }
    }
}


extension LyricsEditView {
    
    @ViewBuilder
    func ControlView() -> some View {
        HStack {
            Toggle("common.preview", isOn: $previewing)
            
            Spacer()
            
            Button("common.import") {
                fileImporterPresented = true
            }
            
            Button("common.export") {
                fileExporterPresented = true
            }
        }
    }
    
    @ViewBuilder
    func previewView() -> some View {
        TimeSyncedLyricsView(lyrics: $lyrics, syncedTime: $previewTime) { lyric in
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
            if self.previewTime > (lyrics.last?.end ?? 0) {
                self.previewTime = 0
            }
        }
    }
}


extension LyricsEditView {
    
    func deleteLyrics() {
        lyrics.removeAll{
            selectedLyrics.contains($0.id)
        }
    }
}
