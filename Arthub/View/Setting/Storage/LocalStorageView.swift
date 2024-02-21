//
//  LocalStorageView.swift
//  Arthub
//
//  Created by 张鸿燊 on 17/2/2024.
//

import SwiftUI

enum LocalStorageType {
    case movie, tvshow, music
}

enum FileDocumentPickerType {
    case movie, tvshow, music
}

struct LocalStorageView: View {
    
    @AppStorage(UserDefaults.localMovieData)
    private var movieData: [String] = [Storage.defaultLocalMovieData]
    @AppStorage(UserDefaults.localMusicData)
    private var musicData: [String] = [Storage.defaultLocalMusicData]
    @AppStorage(UserDefaults.localTVShowData)
    private var tvShowData: [String] = [Storage.defaultLocalTVShowData]
    
    @State private var filePickerPresented: Bool = false
    @State private var filePickerType: FileDocumentPickerType = .movie
    @State private var selection: LocalStorageType? = .movie
    
    @State private var selectedMovieData: Set<String.ID> = Set()
    @State private var selectedMusicData: Set<String.ID> = Set()
    @State private var selectedTVShowData: Set<String.ID> = Set()
    
    var body: some View {
        
        AutoWidthTabView(selection: $selection) {
            LocalMovieDataView().tag(LocalStorageType.movie)
                .tabItem {
                    Text("settings.storage.local.movie")
                }
            LocalTVShowDataView().tag(LocalStorageType.tvshow)
                .tabItem {
                    Text("settings.storage.local.tvshow")
                }
            LocalMusicDataView().tag(LocalStorageType.music)
                .tabItem {
                    Text("settings.storage.local.music")
                }
        }
        .buttonStyle(.borderless)
        .fileImporter(isPresented: $filePickerPresented,
                      allowedContentTypes: [.folder],
                      allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                urls.forEach { url in
                    let url = url.deletingLastPathComponent()
                    let gotAccess = url.startAccessingSecurityScopedResource()
                    if !gotAccess { return }
                    handlePickedFolder(url)
                    url.stopAccessingSecurityScopedResource()
                }
            case .failure(let error):
                print("\(error)")
            }
        }
    }
    
    func handlePickedFolder(_ url: URL) {
        switch filePickerType {
        case .movie:
            if !movieData.contains(where: { $0 == url.relativeString}) {
                movieData.append(url.relativeString)
            }
        case .tvshow:
            if !tvShowData.contains(where: { $0 == url.relativeString}) {
                tvShowData.append(url.relativeString)
            }
        case .music:
            if !musicData.contains(where: { $0 == url.relativeString}) {
                musicData.append(url.relativeString)
            }
        }
        
    }
}


extension LocalStorageView {
    
    @ViewBuilder
    func LocalMovieDataView() -> some View {
        VStack(alignment: .leading) {
            Table(of: String.self, selection: $selectedMovieData) {
                TableColumn("folderpath") { row in
                    Text(URL(string: row)?.relativePath ?? "")
                }
            } rows: {
                ForEach(movieData) { str in
                    TableRow(str)
                }
                .contextMenu {
                    Button("common.delete", role: .destructive) {
                        deleteMovieData()
                    }
                }
            }
            .tableColumnHeaders(.hidden)
            .tableStyle(.inset)
            .alternatingRowBackgrounds()
            
            HStack {
                Button {
                    filePickerType = .movie
                    filePickerPresented = true
                } label: {
                    Image(systemName: "plus")
                }
                Button {
                    deleteMovieData()
                } label: {
                    Image(systemName: "minus")
                }
            }
        }
    }
    
    func deleteMovieData() {
        movieData.removeAll { str in
            selectedMovieData.contains(str.id)
        }
    }
}

extension LocalStorageView {
    
    @ViewBuilder
    func LocalTVShowDataView() -> some View {
        VStack(alignment: .leading) {
            
            Table(of: String.self, selection: $selectedTVShowData) {
                TableColumn("folderpath") { str in
                    Text(URL(string: str)?.relativePath ?? "")
                }
            } rows: {
                ForEach(tvShowData) { str in
                    TableRow(str)
                }
                .contextMenu {
                    Button("common.delete", role: .destructive) {
                        deleteTVShowData()
                    }
                }
            }
            .tableColumnHeaders(.hidden)
            .tableStyle(.inset)
            .alternatingRowBackgrounds()
            
            HStack {
                Button {
                    filePickerPresented = true
                    filePickerType = .tvshow
                } label: {
                    Image(systemName: "plus")
                }
                Button {
                    deleteTVShowData()
                } label: {
                    Image(systemName: "minus")
                }
            }
        }
    }
    
    func deleteTVShowData() {
        tvShowData.removeAll { str in
            selectedTVShowData.contains(str.id)
        }
    }
    
}

extension LocalStorageView {
    
    @ViewBuilder
    func LocalMusicDataView() -> some View {
        VStack(alignment: .leading) {
            
            Table(of: String.self, selection: $selectedMusicData) {
                TableColumn("folderpath") { str in
                    Text(URL(string: str)?.relativePath ?? "")
                }
            } rows: {
                ForEach(musicData) { str in
                    TableRow(str)
                }
                .contextMenu {
                    Button("common.delete", role: .destructive) {
                        deleteMusicData()
                    }
                }
            }
            .tableColumnHeaders(.hidden)
            .tableStyle(.inset)
            .alternatingRowBackgrounds()
            
            HStack {
                Button {
                    filePickerPresented = true
                    filePickerType = .music
                } label: {
                    Image(systemName: "plus")
                }
                Button {
                    deleteMusicData()
                } label: {
                    Image(systemName: "minus")
                }
            }
        }
    }
    
    func deleteMusicData() {
        musicData.removeAll { str in
            selectedMusicData.contains(str.id)
        }
    }
    
}

#Preview {
    LocalStorageView()
}
