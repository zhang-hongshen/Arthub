//
//  LyricsEditView.swift
//  Arthub
//
//  Created by 张鸿燊 on 5/2/2024.
//

import SwiftUI

struct LyricsEditView: View {
    @Binding var lyrics: [LyricSegment]
    @State private var sortOrder = [
        KeyPathComparator(\LyricSegment.startedAt, order: .forward),
        KeyPathComparator(\LyricSegment.endedAt, order: .forward)
    ]
    
    @State private var selectedLyrics: Set<LyricSegment.ID> =  Set()
    @Environment(\.modelContext) private var modelContext
    @State private var previewing: Bool = false
    
    @State var currentTime: TimeInterval = 0

    var body: some View {
        VStack(alignment: .leading) {
            Toggle("lyrics.preview", isOn: $previewing)
            
            Table(of: LyricSegment.self, selection: $selectedLyrics, sortOrder: $sortOrder) {
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
                        do {
                            try modelContext.delete(model: LyricSegment.self,
                                                    where: #Predicate<LyricSegment> { lyric in
                                selectedLyrics.contains(lyric.id)
                            }, includeSubclasses: false)
                        } catch {
                            debugPrint("delete error, \(error)")
                        }
                        
                    }
                }
            }
            .tableStyle(.inset)
            .opacity(previewing ? 0 : 1)
            .overlay {
                previewView()
                    .opacity(previewing ? 1 : 0)
            }
        }
    }
}

extension LyricsEditView {
    @ViewBuilder
    func previewView() -> some View {
        TimeSyncedLyricsView(lyrics: lyrics, currentTime: $currentTime) { lyric in
            currentTime = lyric.startedAt
        }
        .onAppear {
            Timer(timeInterval: 1, repeats: true) { timer in
                currentTime += 1
            }
        }
        .onChange(of: previewing, initial: false) { oldValue, newValue in
            currentTime = 0
        }
    }
}

#Preview {
    LyricsEditView(lyrics: .constant(LyricSegment.examples()))
}
