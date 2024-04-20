//
//  MoviesView.swift
//  Arthub
//
//  Created by 张鸿燊 on 31/1/2024.
//

import SwiftUI
import SwiftData

struct MoviesView: View {
    
    @State private var viewModel = MoviesViewModel()
    @State private var idealCardWidth: CGFloat = Portrait.width(.small)
    
    var body: some View {
        MainView()
            .frame(minWidth: idealCardWidth)
            .safeAreaPadding()
            .toolbar{ ToolbarItems() }
            .searchable(text: $viewModel.searchText, placement: .automatic)
            .task{ viewModel.fetchData() }
            .refreshable{ viewModel.fetchData() }
    }
}

// MARK: Toolbar

extension MoviesView {
    
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

extension MoviesView {
    
    @ViewBuilder
    func MainView() -> some View {
        if viewModel.filteredMovies.isEmpty {
            ContentUnavailableView.search
        } else {
            ScrollView {
                VStack(alignment: .leading) {
                    Group {
                        if !viewModel.watchingMovies.isEmpty {
                            MoviesSection(viewModel.watchingMovies, sectionTitle: "Watching", sortable: false)
                        }
                        MoviesSection(viewModel.recentlyAddedMovies, sectionTitle: "Recently Added", sortable: false)
                        MoviesSection(viewModel.popularityMovies, sectionTitle: "Popular", sortable: false)
                        MoviesSection(viewModel.topRatedMovies, sectionTitle: "Top Rated", sortable: false)
                    }
                    
                    
                    GroupedMoviesSection()
                }
            }
            .scrollIndicators(.never, axes: .vertical)
            .scrollIndicators(.automatic, axes: .horizontal)
        }
    }
}

// MARK: Grouped Movies

extension MoviesView {
    
    @ViewBuilder
    func GroupedMoviesSection() -> some View {
        
        Section {
            ForEach(viewModel.groupedMovies.elements, id: \.key) { (genre, movies) in
                NavigationLink {
                    MovieListView(movies: movies, sortable: true)
                        .navigationTitle(Text(genre))
                } label: {
                    debugPrint("render")
                    return ImageLoader(url: movies.randomElement()?.metadata.backdropPath) {
                        Rectangle().fill(.random.gradient)
                    }
                    .frame(height: Landscape.height(), alignment: .center)
                    .overlay {
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

extension MoviesView {
    
    @ViewBuilder
    func MoviesSection(_ movies: [MovieDetail], sectionTitle: LocalizedStringKey, sortable: Bool) -> some View {
        Section {
            ScrollView(.horizontal) {
                HStack {
                    ForEach(movies.prefix(viewModel.sectionMaxMovie)) { movie in
                        NavigationLink {
                            MovieDetailView(movie: movie)
                                .navigationTitle(movie.metadata.title)
                        } label: {
                            MovieCard(movie: movie, width: idealCardWidth)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            
        } header: {
            HStack(alignment: .center) {
                Text(sectionTitle).font(.title.bold())
                
                Spacer()
                
                if movies.count > viewModel.sectionMaxMovie {
                    NavigationLink("View All") {
                        MovieListView(movies: movies, sortable: sortable)
                            .navigationTitle(Text(sectionTitle))
                    }
                    .tint(.accent)
                    .buttonStyle(.borderless)
                    .hoverEffect()
                }
            }
        }
    }
}
