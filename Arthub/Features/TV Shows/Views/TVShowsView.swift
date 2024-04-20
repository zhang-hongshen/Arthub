//
//  TVShowsView.swift
//  Arthub
//
//  Created by 张鸿燊 on 28/2/2024.
//

import SwiftUI

struct TVShowsView: View {
    
    @State private var viewModel = TVShowsViewModel()
    @State private var idealCardWidth: CGFloat = Portrait.width(.small)

    var body: some View {
        MainView()
            .frame(minWidth: idealCardWidth)
            .safeAreaPadding()
            .focusEffect()
            .toolbar{ ToolbarItems() }
            .searchable(text: $viewModel.searchText)
            .task{ viewModel.fetchData() }
    }
}

// MARK: Toolbar

extension TVShowsView {
    
    @ToolbarContentBuilder
    func ToolbarItems() -> some ToolbarContent {
        ToolbarItemGroup {
            if viewModel.isFetchingData {
                ProgressView()
                #if !os(tvOS)
                .controlSize(.small)
                #endif
            } else {
                Button("Refresh", systemImage: "arrow.clockwise", action: viewModel.fetchData)
            }
        }
    }
}

extension TVShowsView {
    
    @ViewBuilder
    func MainView() -> some View {
        if viewModel.filteredTVShows.isEmpty {
            ContentUnavailableView.search
        } else {
            ScrollView {
                VStack(alignment: .leading) {
                    TVShowsSection(viewModel.recentlyAddedTVShows, sectionTitle: "Recently Added", sortable: false)
                    TVShowsSection(viewModel.popularityTVShows, sectionTitle: "Popular", sortable: false)
                    GroupedTVShowsSection()
                }
            }
            .scrollIndicators(.never, axes: .vertical)
            .scrollIndicators(.automatic, axes: .horizontal)
        }
    }
    
    @ViewBuilder
    func TVShowsSection(_ tvShows: [TVShowDetail], sectionTitle: LocalizedStringKey, sortable: Bool) -> some View {
        Section {
            ScrollView(.horizontal) {
                HStack {
                    ForEach(tvShows.prefix(viewModel.sectionMaxTVShow)) { tvShow in
                        NavigationLink {
                            TVShowDetailView(tvShow: tvShow)
                                .navigationTitle(tvShow.metadata.name)
                        } label: {
                            TVShowCard(tvShow: tvShow, width: idealCardWidth)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        } header: {
            HStack(alignment: .center) {
                Text(sectionTitle).font(.title.bold())
                
                Spacer()
                
                if tvShows.count > viewModel.sectionMaxTVShow {
                    NavigationLink("View All") {
                        TVShowListView(tvShows: tvShows, sortable: sortable)
                    }
                    .tint(.accent)
                    .buttonStyle(.borderless)
                    .hoverEffect()
                }
                
            }
        }
    }

}


extension TVShowsView {
    
    @ViewBuilder
    func GroupedTVShowsSection() -> some View {
        Section {
            ForEach(viewModel.groupedTVShows.elements, id: \.key) { (genre, tvShows) in
                NavigationLink {
                    TVShowListView(tvShows: tvShows, sortable: true)
                } label: {
                    ImageLoader(url: tvShows.randomElement()?.metadata.backdropPath) {
                        Rectangle().fill(.random.gradient)
                    }
                    .frame(height: Landscape.height(), alignment: .center)
                    .overlay(alignment: .center) {
                        Text(genre).font(.largeTitle.bold())
                    }
                    .cornerRadius()
                }
                .buttonStyle(.borderless)
            }
        } header: {
            Text("Genres").font(.title.bold())
        }
    }
}
