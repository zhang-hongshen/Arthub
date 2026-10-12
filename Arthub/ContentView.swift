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
    @State private var currentTab: AppTab? = .movies
    // ViewModels live here so switching tabs doesn't discard scan results.
    @State private var moviesViewModel = MoviesViewModel()
    @State private var tvShowsViewModel = TVShowsViewModel()
    @State private var musicViewModel = MusicViewModel()
    #if os(macOS)
    /// Sidebar (200) + `MusicView`'s 600pt minimum + inspector (320) + the two dividers.
    private let musicMinWindowWidth: CGFloat = 200 + 600 + 320 + 2
    #endif

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
    }
}

extension ContentView {
    
    @ViewBuilder
    func NavigationView() -> some View {
        #if canImport(UIKit)
        if UIDevice.isIPhone {
            NavigationTabView()
        } else {
            NavigationListView()
        }
        #else
        NavigationListView()
        #endif
    }
    
    @ViewBuilder
    func NavigationTabView() -> some View {
        TabView(selection: $currentTab){
            NavigationStack { MoviesView(viewModel: moviesViewModel) }.tag(AppTab.movies)
                .tabItem {
                    Text(AppTab.movies.localizedName)
                    Image(systemName: AppTab.movies.systemImage)
                }

            NavigationStack { TVShowsView(viewModel: tvShowsViewModel) }.tag(AppTab.tvshows)
                .tabItem {
                    Text(AppTab.tvshows.localizedName)
                    Image(systemName: AppTab.tvshows.systemImage)
                }


            NavigationStack { MusicView(viewModel: musicViewModel) }.tag(AppTab.music)
                .tabItem {
                    Text(AppTab.music.localizedName)
                    Image(systemName: AppTab.music.systemImage)
                }


            NavigationStack { LibraryView(library: nil) }.tag(AppTab.files)
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
        @Bindable var state = state
        NavigationSplitView(columnVisibility: $state.columnVisibility,
                            preferredCompactColumn: .constant(.sidebar)) {

            SidebarView()
                .toolbar(removing: state.toolbarRemove)
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
            case .settings:
                NavigationStack { SettingsView().navigationTitle("Settings") }
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
        // AppKit's split view throws the same exception whenever the window is narrower than
        // sidebar + detail + inspector, e.g. when the inspector opens in an 800pt window and the
        // window has to grow mid-layout. So keep the window wide enough for all three while Music is
        // shown, and while its inspector is open, so it can reappear safely when Music is reselected.
        .frame(minWidth: currentTab == .music || musicViewModel.inspectorPresented ? musicMinWindowWidth : nil)
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
                    ForEach(libraries, id: \.self) { library in
                        Label(libraryIndex.displayName(for: library),
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
            #if os(iOS)
            // iPad has no Settings window, and adding folders lives in Settings.
            Section {
                Label(AppTab.settings.localizedName,
                      systemImage: AppTab.settings.systemImage)
                .tag(AppTab.settings)
            }
            #endif
        }
    }
    
}

#Preview {
    ContentView()
}
