//
//  LyricsEditView.swift
//  Arthub
//
//  Created by 张鸿燊 on 5/2/2024.
//

import SwiftUI

struct LyricsEditView: View {
    @State var lyricsURL: URL?
    @State private var sortOrders = [
        KeyPathComparator(\Lyric.startedAt, order: .forward),
        KeyPathComparator(\Lyric.endedAt, order: .forward)
    ]
    
    @State private var selectedLyrics: Set<Lyric.ID> =  Set()
    @State private var previewing: Bool = false
    @State private var fileExporterPresented: Bool = false
    @State private var fileImporterPresented: Bool = false
    @State private var currentTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var lyrics: [Lyric] = []
    
    var body: some View {
        VStack(alignment: .leading) {
            ControlView()
            
            Table(of: Lyric.self, selection: $selectedLyrics, sortOrder: $sortOrders) {
                TableColumn("lyric.startedAt", value: \.startedAt) { row in
                    Text(row.startedAt.description)
                }
                TableColumn("lyric.endedAt", value: \.endedAt) { row in
                    Text(row.endedAt.description)
                }
                TableColumn("lyric.content", value: \.content)
            } rows: {
                ForEach(lyrics) { lyric in
                    TableRow(lyric)
                }
                .contextMenu {
                    Button("common.delete", role: .destructive) {
                        deleteLyrics()
                    }
                }
            }
            .opacity(previewing ? 0 : 1)
            .overlay {
                previewView()
                    .opacity(previewing ? 1 : 0)
            }
            .onChange(of: sortOrders, initial: true) { _,  newValue in
                self.lyrics.sort(using: newValue)
            }
            .onDeleteCommand {
                deleteLyrics()
            }
        }
        .task {
            guard let url = lyricsURL else {
                return
            }
            self.lyrics = Lyric.loadLyrics(url: url)
        }
        #if os(macOS)
        .fileImporter(isPresented: $fileImporterPresented, 
                      allowedContentTypes: [.xml]) { result in
            switch result {
            case .success(let url):
                lyrics = TTMLParser.shared.parse(url: url)
                print("parse success")
            case .failure(let error):
                print("Failed to import document: \(error)")
            }
        }
        #endif
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
        TimeSyncedLyricsView(lyrics: lyrics, currentTime: $currentTime) { lyric in
            selectedLyrics = Set(arrayLiteral: lyric.id)
        }
        .onChange(of: previewing, initial: false) { oldValue, newValue in
            currentTime = 0
            if newValue {
                timer = Timer(timeInterval: 1, repeats: true) { timer in
                    currentTime += 1
                }
            } else {
                if let timer = self.timer {
                    timer.invalidate()
                    self.timer = nil
                }
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
