//
//  ContentView.swift
//  Arthub
//
//  Created by 张鸿燊 on 31/1/2024.
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ContentView: View {
    
    fileprivate enum AppTab: Identifiable, Hashable {
        case movies, tvshows, music, files
        case library(String)
        case settings
        
        var id: Self { self }
        
        var localizedName: LocalizedStringKey {
            switch self {
            case .movies:
                LocalizedStringKey("Movies")
            case .tvshows:
                LocalizedStringKey("TV Shows")
            case .music:
                LocalizedStringKey("Music")
            case .files:
                LocalizedStringKey("All Files")
            case .library(let url):
                LocalizedStringKey(url)
            case .settings:
                LocalizedStringKey("Settings")
            }
        }
        
        var systemImage: String {
            switch self {
            case .movies:
                "film"
            case .tvshows:
                "tv"
            case .music:
                "music.note"
            case .files:
                "folder"
            case .library(_):
                "folder"
            case .settings:
                "gear"
            }
        }
    }
    
    @Environment(\.scenePhase) private var scenePhase
    @State private var libraryIndex = LibraryViewModel.shared
    @State private var folderError: String?
    @State private var currentTab: AppTab? = .movies
    @State private var fileImporterPresented: Bool = false
    // ViewModels live here so switching tabs doesn't discard scan results.
    @State private var moviesViewModel = MoviesViewModel()
    @State private var tvShowsViewModel = TVShowsViewModel()
    @State private var musicViewModel = MusicViewModel()

    @AppStorage(UserDefaults.library)
    private var libraries: [String] = []

    @Environment(WindowState.self)
    private var state

    var body: some View {
        NavigationView()
            .background(.ultraThinMaterial)
            .animation(.easeInOut, value: state.columnVisibility)
            .task(id: libraries) {
                while !Task.isCancelled {
                    if scenePhase == .active { await libraryIndex.refresh() }
                    do { try await Task.sleep(for: .seconds(30)) }
                    catch { return }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await libraryIndex.refresh() } }
            }
            .onChange(of: libraryIndex.revision, initial: true) { _, _ in
                moviesViewModel.fetchData(refreshLibrary: false)
                tvShowsViewModel.fetchData(refreshLibrary: false)
                musicViewModel.fetchData(refreshLibrary: false)
            }
            .onChange(of: libraries) { _, newValue in
                if case .library(let library) = currentTab, !newValue.contains(library) {
                    currentTab = .movies
                }
            }
            .alert("Unable to Add Folder", isPresented: Binding(
                get: { folderError != nil }, set: { if !$0 { folderError = nil } })) {
                Button("OK") { folderError = nil }
            } message: { Text(folderError ?? "") }
    }
}

extension ContentView {
    
    @ViewBuilder
    func NavigationView() -> some View {
        #if canImport(UIKit)
        Group {
            if UIDevice.isIPhone {
                NavigationTabView()
            } else {
                NavigationListView()
            }
        }.fileImporter(isPresented: $fileImporterPresented,
                       allowedContentTypes: [.folder],
                       onCompletion: { result in
             switch result {
             case .success(let url):
                 addLibrary(url)
             case .failure(let error):
                 print(error.localizedDescription)
             }
         })
        #else
        NavigationListView()
            .fileImporter(isPresented: $fileImporterPresented,
                                           allowedContentTypes: [.folder],
                          onCompletion: { result in
                switch result {
                case .success(let url):
                    addLibrary(url)
                case .failure(let error):
                    print(error.localizedDescription)
                }
            })
        #endif
            
    }
    
    @ViewBuilder
    func NavigationTabView() -> some View {
        TabView(selection: $currentTab){
            NavigationStack { MoviesView(viewModel: moviesViewModel).toolbar { ToolbarItems() } }.tag(AppTab.movies)
                .tabItem {
                    Text(AppTab.movies.localizedName)
                    Image(systemName: AppTab.movies.systemImage)
                }

            NavigationStack { TVShowsView(viewModel: tvShowsViewModel).toolbar { ToolbarItems() } }.tag(AppTab.tvshows)
                .tabItem {
                    Text(AppTab.tvshows.localizedName)
                    Image(systemName: AppTab.tvshows.systemImage)
                }


            NavigationStack { MusicView(viewModel: musicViewModel).toolbar { ToolbarItems() } }.tag(AppTab.music)
                .tabItem {
                    Text(AppTab.music.localizedName)
                    Image(systemName: AppTab.music.systemImage)
                }


            NavigationStack { LibraryView(library: nil).toolbar { ToolbarItems() } }.tag(AppTab.files)
                .tabItem { Label("Files", systemImage: "folder") }

            NavigationStack { SettingsView() }.tag(AppTab.settings)
                .tabItem {
                    Text(AppTab.settings.localizedName)
                    Image(systemName: AppTab.settings.systemImage)
                }
        }
    }

    @ViewBuilder
    func NavigationListView() -> some View {
        NavigationSplitView(columnVisibility: Binding(
            get: { state.columnVisibility },
            set: { state.setColumnVisibility($0) }
        ), preferredCompactColumn: .constant(.sidebar)) {

            SidebarView()
                .toolbar(removing: state.toolbarRemove)
                .toolbar(content: ToolbarItems)
                .navigationSplitViewColumnWidth(min: 180, ideal: 200)

        } detail : {
            switch currentTab {
            case .movies:
                NavigationStack {
                    MoviesView(viewModel: moviesViewModel).navigationTitle("Movies")
                }
            case .tvshows:
                NavigationStack {
                    TVShowsView(viewModel: tvShowsViewModel).navigationTitle("TV Shows")
                }
            case .music:
                NavigationStack {
                    MusicView(viewModel: musicViewModel).navigationTitle("Music")
                }
            case .files:
                NavigationStack { LibraryView(library: nil) }
            case .library(let url):
                NavigationStack { LibraryView(library: url) }.id(url)
            default: EmptyView()
            }
        }
        #if os(macOS)
        .inspector(isPresented: Binding(
            get: { currentTab == .music && !musicViewModel.playerPresented && musicViewModel.inspectorPresented },
            set: { musicViewModel.inspectorPresented = $0 })) {
            // Pin the inspector's own min/ideal size so it never depends on its content (song title
            // length, segmented control, text fields). Otherwise the window's size constraints and the
            // inspector's hosted split view kept re-invalidating each other until AppKit threw
            // "more Update Constraints in Window passes than there are views in the window".
            MusicInspector(viewModel: musicViewModel)
                .frame(minWidth: 0, idealWidth: 320, maxWidth: .infinity,
                       minHeight: 0, idealHeight: 0, maxHeight: .infinity)
                .inspectorColumnWidth(min: 300, ideal: 320, max: 400)
        }
        #endif
    }
    
    @ViewBuilder
    func SidebarView() -> some View {
        List(selection: $currentTab) {
            Text(verbatim: "Arthub")
                .font(.largeTitle)
                .fontWeight(.semibold)
            Section {
                Label(AppTab.movies.localizedName,
                      systemImage: AppTab.movies.systemImage)
                .tag(AppTab.movies)

                Label(AppTab.tvshows.localizedName,
                      systemImage: AppTab.tvshows.systemImage)
                .tag(AppTab.tvshows)

                Label(AppTab.music.localizedName,
                      systemImage: AppTab.music.systemImage)
                .tag(AppTab.music)
            }   header: {
                Text("Home")
            }
            if !libraries.isEmpty {
                Section {
                    ForEach(libraries) { library in
                        Label(libraryDisplayName(library),
                              systemImage: libraryIndex.offlineLibraries.contains(library)
                              ? "externaldrive.badge.exclamationmark" : AppTab.library(library).systemImage)
                        .tag(AppTab.library(library))
                        .contextMenu {
                            #if canImport(AppKit)
                            Button("Reveal in Finder", systemImage: "folder") {
                                if let url = libraryIndex.folderURL(for: library) {
                                    NSWorkspace.shared.selectFile(nil,
                                        inFileViewerRootedAtPath: url.path)
                                }
                            }
                            #endif
                            DeleteButton {
                                if let index = libraries.firstIndex(of: library) {
                                    libraries.remove(at: index)
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        libraries.remove(atOffsets: indexSet)
                    }
                }   header: {
                    Text("Library")
                }
            }
        }
    }
    
    @ToolbarContentBuilder
    func ToolbarItems() -> some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button("", systemImage: "plus") {
                fileImporterPresented = true
            }
        }
    }
    
}

extension ContentView {
    func addLibrary(_ url: URL) {
        // fileImporter hands over a security-scoped URL; keep its absolute
        // form and skip folders already in the list.
        let entry = url.absoluteString
        if libraries.contains(entry) {
            do { try libraryIndex.rememberFolder(url); Task { await libraryIndex.refresh() } }
            catch { folderError = error.localizedDescription }
            return
        }
        do {
            try libraryIndex.rememberFolder(url)
            libraries.append(entry)
        } catch { folderError = error.localizedDescription }
    }

    func libraryDisplayName(_ library: String) -> String {
        libraryIndex.folderURL(for: library)?.lastPathComponent ?? library
    }
}

#Preview {
    ContentView()
}
