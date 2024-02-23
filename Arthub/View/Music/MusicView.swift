//
//  MusicView.swift
//  Arthub
//
//  Created by 张鸿燊 on 31/1/2024.
//

import SwiftUI
import Logging
import UniformTypeIdentifiers
import MediaPlayer

enum ViewLayout: String, CaseIterable, Identifiable {
    case grid, list
    var id: Self { self }
}

struct MusicView: View {
    
    @EnvironmentObject private var player : ArthubAudioPlayer
    @Environment(WindowState.self) private var windowState
    
    @State private var musics: [Music] = []
    @State private var selectedLayout: ViewLayout = .grid
    @State private var selectedOrderProperty: MusicOrderProperty = .createdAt
    @State private var selectedGroup: MusicGroup = .none
    @State private var selectedOrder: SortOrder = .forward
    @State private var inspectorPresented: Bool = false
    @State private var idealCardWidth: CGFloat = 180
    @State private var selectedMusicID: UUID? = nil
    @State private var playerPresented: Bool = false
    @State private var dropTrageted: Bool = false
    
    @AppStorage(UserDefaults.localMusicData)
    private var musicData: [String] = [Storage.defaultLocalMusicData]
    
    private var selectedMusic: Music?  {
        return musics.first(where: { $0.id == selectedMusicID }) ?? nil
    }

    @State private var currentMusic: Music? = nil
    
    private var sortOrder: KeyPathComparator<Music> {
        switch selectedOrderProperty {
        case .createdAt: KeyPathComparator(\Music.createdAt, order: selectedOrder)
        case .title: KeyPathComparator(\Music.title, order: selectedOrder)
        case .releaseDate: KeyPathComparator(\Music.releaseDate, order: selectedOrder)
        }
    }
    
    var body: some View {
        MainView()
            .frame(minWidth: idealCardWidth)
            .safeAreaPadding(10)
            .navigationTitle("music")
            .inspector(isPresented: $inspectorPresented) {
                InspectorView()
                    .safeAreaPadding(10)
            }
            .toolbarRole(.editor)
            .toolbar {
        
                #if os(macOS)
                ToolbarItemGroup(placement: .primaryAction) {
                    ToolbarMusicPlayerView()
                }
                #endif
                
                ToolbarItemGroup {
                    ToolbarItemView()
                }
            }
            .navigationDestination(isPresented: $playerPresented){
                if let music = selectedMusic,
                   let i = musics.firstIndex(where: { $0.id == music.id }) {
                    MusicPlayerView(musics: Array(musics[i..<musics.count]) + Array(musics[0..<i]))
                }
            }
            .dropDestination(for: URL.self) { urls, location in
                if urls.isEmpty || !dropTrageted {
                    return false
                }
                // TODO
                return true
            } isTargeted: { targetd in
                dropTrageted = targetd
            }
            .onChange(of: player.currentIndex, initial: true) { oldValue, newValue in
                guard let index = newValue else {
                    self.currentMusic = nil
                    return
                }
                self.currentMusic = musics[index]
            }
            .task(priority: .userInitiated) {
                var urls: [URL] = []
                musicData.forEach { data in
                    if let url = URL(string: data) {
                        urls.append(url)
                    }
                }
                do {
                    try await self.fetchMusics(urls: urls)
                } catch {
                    Logger.shared.error("fetchMusic error, \(error)")
                }
            }
    }
}

extension MusicView {
    
    @ViewBuilder
    func ToolbarMusicPlayerView() -> some View {
        HStack {
            
            Group {
                Button {
                    player.previousTrack()
                } label: {
                    Image(systemName: "backward")
                }
                
                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.playerState == .playing ? "pause" : "play")
                }
                .keyboardShortcut(.space, modifiers: [])
                
                Button {
                    player.nextTrack()
                } label: {
                    Image(systemName: "forward")
                }
            }
            .symbolVariant(.fill)
            
            
            AsyncImage(url: currentMusic?.album?.cover,
                       transaction: .init(animation: .smooth)
            ) { phase in
                switch phase {
                case .empty:
                    DefaultImageView()
                case .success(let image):
                    image.resizable().scaledToFit()
                case .failure(let error):
                    ErrorImageView(error: error)
                @unknown default:
                    fatalError()
                }
            }
            .onTapGesture {
                playerPresented = true
            }
            .frame(width: 50, height: 50)
            
            VStack(alignment: .center) {
                Text(currentMusic?.title ?? "-")
                Text("\(currentMusic?.artists.formatted() ?? "") - \(currentMusic?.album?.title ?? "")")
                    .opacity(0.5)
            }
        }
    }
}
extension MusicView {
    
    @ViewBuilder
    func ToolbarItemView() -> some View {
        
        Picker("toolbar.layout", selection: $selectedLayout) {
            Label("toolbar.layout.grid", systemImage: "square.grid.2x2").tag(ViewLayout.grid)
            Label("toolbar.layout.list", systemImage: "list.bullet").tag(ViewLayout.list)
        }
        .pickerStyle(.segmented)
        
        Menu {
            Group {
                Picker("", selection: $selectedGroup) {
                    Text("common.none").tag(MusicGroup.none)
                    Text("music.releaseYear").tag(MusicGroup.releaseYear)
                }
                
                Picker("", selection: $selectedOrderProperty) {
                    Text("music.title").tag(MusicOrderProperty.title)
                    Text("music.createdAt").tag(MusicOrderProperty.createdAt)
                    Text("music.releaseDate").tag(MusicOrderProperty.releaseDate)
                }
                
                Picker("", selection: $selectedOrder) {
                    Text("sortOrder.ascending").tag(SortOrder.forward)
                    Text("sortOrder.descending").tag(SortOrder.reverse)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            Image(systemName: "square.grid.3x1.below.line.grid.1x2")
        }
        
        Button("toolbar.showInspector", systemImage: "sidebar.right") {
            inspectorPresented.toggle()
        }
    }
}

extension MusicView {

    @ViewBuilder
    func MainView() -> some View {
        GeometryReader { proxy in
            
            var columns: [GridItem] {
                switch selectedLayout {
                case .grid:
                    Array(repeating: .init(.fixed(idealCardWidth), alignment: .top), count: Int(proxy.size.width / idealCardWidth))
                case .list:
                    Array(repeating: .init(.fixed(proxy.size.width), alignment: .leading), count: 1)
                }
            }
            
            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading) {
                    ForEach($musics) { music in
                        let selected = selectedMusicID == music.id
                        Group {
                            switch selectedLayout {
                            case.grid:
                                MusicCardView(music: music, frameWidth: idealCardWidth)
                                    .scaleEffect(selected)
                            case.list:
                                MusicListItemView(music: music)
                                    .safeAreaPadding(5)
                                    .background {
                                        RoundedRectangle(cornerRadius: .defaultCornerRadius)
                                            .fill(selected ? Color.selectedTextColor.opacity(0.4) : Color.clear)
                                    }
                                    .tint(selected ? Color.selectedTextColor : Color.textColor)
                            }
                        }.tag(music.id)
                        .onTapGesture(count: 1) {
                            selectedMusicID = music.id
                        }
                        .simultaneousGesture(
                            TapGesture(count: 2)
                                .onEnded {
                                    playerPresented = true
                                }
                        )
                    }
                }
            }
            .scrollIndicators(.never)
        }
        
    }
    
    @ViewBuilder
    func InspectorView() -> some View {
        if let music = selectedMusic {
            MusicInspectorView(music: Binding(
                get: { music },
                set: { _ in }))
        } else {
            Text("inspector.empty").font(.title)
        }
    }

}

extension MusicView {
    
    func fetchMusics(urls: [URL]) async throws {
        for musicDataURL in urls {
            let artistURLs = try FileManager.default
                .contentsOfDirectory(at: musicDataURL,
                                     includingPropertiesForKeys: [.isDirectoryKey],
                                     options: [.skipsHiddenFiles])
            for artistURL in artistURLs {
                var artists: [Artist] = []
                for artistName in artistURL.fileName.split(separator: "&") {
                    artists.append(Artist(name: artistName.trimmingCharacters(in: .whitespaces)))
                }
                let albumURLs = try FileManager.default
                    .contentsOfDirectory(at: artistURL,
                                         includingPropertiesForKeys: [.isRegularFileKey],
                                         options: [.skipsHiddenFiles])
                for albumURL in albumURLs {
                    let album = Album(title: albumURL.fileName, artists: artists)
                    let urls = try FileManager.default
                        .contentsOfDirectory(at: albumURL,
                                             includingPropertiesForKeys: [.isRegularFileKey],
                                             options: [.skipsHiddenFiles])
                    for url in urls {
                        if url.isImage && url.fileName.lowercased() == "cover"{
                            album.cover = url
                        } else if url.isAudio {
                            if let matches = url.fileName.wholeMatch(of: RegexPattern.musicName) {
                                let trackNum = Int(matches.output.trackNum ?? "")
                                let discNum = Int(matches.output.discNum ?? "")
                                let title = String(matches.output.title)
                                let music = Music(title: title, url: url, album: album,
                                                  trackNum: trackNum, discNum: discNum)
                                
                                let ttmlURL = url.deletingPathExtension().appendingPathExtension(UTType.ttml.preferredFilenameExtension!)
                                if FileManager.default.fileExists(at: ttmlURL) {
                                    music.lyrics = ttmlURL
                                }
                                try await music.loadMetadata()
                                musics.append(music)
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    MusicView()
        .environmentObject(ArthubAudioPlayer(AudioNowPlayableBehavior()))
        .environment(WindowState())
}
