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
#endif

struct ContentView: View {
    
    fileprivate enum AppTab: Identifiable, Hashable {
        case movies, tvshows, songs
        case feed(FeedDetail)
        case settings
        
        var id: Self { self }
        
        var localizedName: LocalizedStringKey {
            switch self {
            case .movies:
                LocalizedStringKey("Movies")
            case .feed(let feed):
                LocalizedStringKey(feed.title)
            case .tvshows:
                LocalizedStringKey("TV Shows")
            case .songs:
                LocalizedStringKey("Songs")
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
            case .songs:
                "music.note"
            case .settings:
                "gear"
            case .feed(_):
                "link"
            }
        }
    }
    
    @State private var currentTab: AppTab? = .movies
    @State private var feed: FeedDetail?
    @State private var library: LibraryDetail?
    @State private var fileImporterPresented: Bool = false
    
    @State private var state =  WindowState()
    @State private var videoPlayer = ArthubVideoPlayer()
    @State private var audioPlayer = ArthubAudioPlayer()
    
    @Query
    private var feeds: [FeedDetail] = []
    
    @AppStorage(UserDefaults.localMoviesData)
    private var moviesData: [String] = []
    @AppStorage(UserDefaults.localMusicData)
    private var musicData: [String] = []
    @AppStorage(UserDefaults.localTVShowsData)
    private var tvShowsData: [String] = []
    
    var body: some View {
        MainView()
            .background(.ultraThinMaterial)
            .environment(state)
            .environment(videoPlayer)
            .environment(audioPlayer)
            .animation(.easeInOut, value: state.columnVisibility)
    }
}

extension ContentView {
    
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
                
                Label(AppTab.songs.localizedName,
                      systemImage: AppTab.songs.systemImage)
                .tag(AppTab.songs)
            }   header: {
                Text("Home")
            }
                
            Section {
                
            } header: {
                Text("Files")
            }
                
            Section {
                ForEach(feeds) { feed in
                    Label(AppTab.feed(feed).localizedName,
                          systemImage: AppTab.feed(feed).systemImage)
                    .tag(AppTab.feed(feed))
                }
            } header: {
                Text("Feeds")
            }
                
        }
        .listStyle(.sidebar)
        .fileImporter(isPresented: $fileImporterPresented,
                      allowedContentTypes: [.folder],
                      onCompletion: { result in
            switch result {
            case .success(let url):
                appendURL(url)
            case .failure(let error):
                print(error.localizedDescription)
            }
        })
        .sheet(item: $feed, onDismiss: { feed = nil }){
            FeedEditionView(feed: $0)
        }
        .sheet(item: $library, onDismiss: { library = nil }){
            LibraryEditionView(library: $0)
        }
    }
    
    
    @ToolbarContentBuilder
    func ToolbarItems() -> some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Menu("Add Library", systemImage: "plus") {
                Button("Local Folder", systemImage: "folder.badge.plus") {
                    fileImporterPresented = true
                }
                
                Button("Subscribe Link", systemImage: "link.badge.plus") {
                    feed = FeedDetail()
                }
                
                Button("Network Share", systemImage: "externaldrive.badge.plus") {
                    library = LibraryDetail()
                }
            }
            .menuIndicator(.hidden)
        }
    }
    
    @ViewBuilder
    func OtherNavigationView() -> some View {
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
                    MoviesView().navigationTitle("Movies")
                }
            case .tvshows:
                NavigationStack {
                    TVShowsView().navigationTitle("TV Shows")
                }
            case .songs:
                NavigationStack {
                    MusicView().navigationTitle("Music")
                }
            default: EmptyView()
            }
        }
    }
    
    @ViewBuilder
    func NavigationTabView() -> some View {
        TabView(selection: $currentTab){
            NavigationStack { MoviesView().toolbar { ToolbarItems() } }.tag(AppTab.movies)
                .tabItem {
                    Text(AppTab.movies.localizedName)
                    Image(systemName: AppTab.movies.systemImage)
                }
            
            NavigationStack { TVShowsView().toolbar { ToolbarItems() } }.tag(AppTab.tvshows)
                .tabItem {
                    Text(AppTab.tvshows.localizedName)
                    Image(systemName: AppTab.tvshows.systemImage)
                }
                
            
            NavigationStack { MusicView().toolbar { ToolbarItems() } }.tag(AppTab.songs)
                .tabItem {
                    Text(AppTab.songs.localizedName)
                    Image(systemName: AppTab.songs.systemImage)
                }
            
            
            NavigationStack { SettingsView() }.tag(AppTab.settings)
                .tabItem {
                    Text(AppTab.settings.localizedName)
                    Image(systemName: AppTab.settings.systemImage)
                }
        }
        .fileImporter(isPresented: $fileImporterPresented,
                      allowedContentTypes: [.folder],
                      onCompletion: { result in
            switch result {
            case .success(let url):
                appendURL(url)
            case .failure(let error):
                print(error.localizedDescription)
            }
        })
        .sheet(item: $feed, onDismiss: { feed = nil }){
            FeedEditionView(feed: $0)
        }
        .sheet(item: $library, onDismiss: { library = nil }){
            LibraryEditionView(library: $0)
        }
    }
    
    
    
    @ViewBuilder
    func MainView() -> some View {
        #if canImport(UIKit)
        Group {
            if UIDevice.isIPhone {
                NavigationTabView()
            } else {
                OtherNavigationView()
            }
        }
        #else
        OtherNavigationView()
        #endif
    }
}

extension ContentView {
    func appendURL(_ url: URL) {
        let userDefaults = UserDefaults.standard
        switch currentTab {
        case .movies : userDefaults.append(forKey: UserDefaults.localMoviesData, newElement: url.relativeString)
        case .songs : userDefaults.append(forKey: UserDefaults.localMusicData, newElement: url.relativeString)
        case .tvshows: userDefaults.append(forKey: UserDefaults.localTVShowsData, newElement: url.relativeString)
        default: break
        }
    }
}

#Preview {
    ContentView()
}
