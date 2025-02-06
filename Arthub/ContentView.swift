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
        case movies, tvshows, music
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
            case .settings:
                "gear"
            }
        }
    }
    
    @State private var currentTab: AppTab? = .movies
    @State private var fileImporterPresented: Bool = false
    
    
    @AppStorage(UserDefaults.library)
    private var libraries: [String] = []
    
    @Environment(WindowState.self)
    private var state
    
    var body: some View {
        MainView()
            .background(.ultraThinMaterial)
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
                
                Label(AppTab.music.localizedName,
                      systemImage: AppTab.music.systemImage)
                .tag(AppTab.music)
            }   header: {
                Text("Home")
            }
            Section {
                ForEach(libraries) {library in
                    Text(library)
                }
            }   header: {
                Text("Library")
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
    }
    
    
    @ToolbarContentBuilder
    func ToolbarItems() -> some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button("", systemImage: "plus") {
                fileImporterPresented = true
            }
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
            case .music:
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
                
            
            NavigationStack { MusicView().toolbar { ToolbarItems() } }.tag(AppTab.music)
                .tabItem {
                    Text(AppTab.music.localizedName)
                    Image(systemName: AppTab.music.systemImage)
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
        userDefaults.append(forKey: UserDefaults.library, newElement: url.relativeString)
    }
}

#Preview {
    ContentView()
}
