//
//  MusicInspectorView.swift
//  Arthub
//
//  Created by 张鸿燊 on 1/2/2024.
//

import SwiftUI

struct MusicInspectorView: View {
    
    enum Tab {
        case info, lyrics
    }
    
    @Bindable var music: MusicDetail
    @State private var fileImporterPresented = false
    @State private var currentTab: Tab? = .info
    @State private var error: ArthubError?
    
    var body: some View {
        
        TabView(selection: $currentTab) {
            Group {
                InfoView().tag(Tab.info).tabItem {
                    Text("Info")
                }
                LyricsEditView(music: music).tag(Tab.lyrics).tabItem {
                    Text("Lyrics")
                }
            }
            .padding()
        }
        .safeAreaPadding(.top)
        .alert(error: $error)
    }
}

extension MusicInspectorView {
    
    @ViewBuilder
    func InfoView() -> some View {
        GeometryReader { proxy in
            ScrollView {
                ImageLoader(data: music.album.cover) {
                    ImageButton(systemImage: "music.note")
                }
                    .frame(width: proxy.size.width,
                           height: proxy.size.width)
                    .cornerRadius()
                    #if !os(tvOS)
                    .dropDestination(for: URL.self) { urls, _ in
                        guard let url = urls.first, url.isImage else { return false }
                        return importAlbumCover(url)
                    }
                    .fileImporter(isPresented: $fileImporterPresented, allowedContentTypes: [.image]) { result in
                        switch result {
                        case .success(let url): importAlbumCover(url)
                        case .failure(let error): print(error.localizedDescription)
                        }
                    }
                    #endif
                    InfoView1()
            }
            .scrollIndicators(.never)
        }
    }
    
    
    @ViewBuilder
    func InfoView1() -> some View {
        Form {
            LabeledContent("Title") {
                TextField(text: $music.title,
                          prompt: Text(""),
                          label: { EmptyView() })
            }
            
            LabeledContent("Artist") {
                TextField(text: $music.artist.name,
                          prompt: Text(""),
                          label: { EmptyView() })
            }
            
            LabeledContent("Composer") {
                TextField(text: $music.composer,
                          prompt: Text(""),
                          label: { EmptyView() })
            }
            
            LabeledContent("Lyricist") {
                TextField(text: $music.lyricist,
                          prompt: Text(""),
                          label: { EmptyView() })
            }
            
            LabeledContent("Arranger") {
                TextField(text: $music.arranger,
                          prompt: Text(""),
                          label: { EmptyView() })
            }
            
            LabeledContent("Album") {
                TextField(text: $music.album.title,
                          prompt: Text(""),
                          label: { EmptyView() })
            }
            
            LabeledContent("Album Artist") {
                TextField(text: $music.album.artist.name,
                          prompt: Text(""),
                          label: { EmptyView() })
            }
            LabeledContent("Track") {
                TextField(value: $music.trackNumber,
                          format: .number,
                          prompt: Text(""),
                          label: { EmptyView() })
                .fixedSize()
            }
            
            LabeledContent("Disc Number") {
                TextField(value: $music.discNumber,
                          format: .number,
                          prompt: Text(""),
                          label: { EmptyView() })
                    .fixedSize()
            }
            
        }
        .font(.title3)
    }
}

extension MusicInspectorView {
    
    func importAlbumCover(_ url: URL) -> Bool {
        do {
            music.album.cover = try Data(contentsOf: url)
        } catch {
            self.error = ArthubError.error(error)
            return false
        }
        return true
    }
}
