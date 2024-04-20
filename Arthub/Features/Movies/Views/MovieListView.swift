//
//  MovieListView.swift
//  Arthub
//
//  Created by 张鸿燊 on 7/3/2024.
//

import SwiftUI

struct MovieListView: View {
    
    @State var movies: [MovieDetail] = []
    @State var sortable = true
    @State private var orderProperty: MovieOrderProperty = .title
    @State private var order: SortOrder = .forward
    @State private var searchText: String = ""
    @State private var columns: [GridItem] = []

    private var filteredMovies: [MovieDetail] {
        var filtered: [MovieDetail] = movies
        if !searchText.isEmpty {
            let search = searchText.lowercased()
            filtered = movies.filter {
                $0.metadata.title.lowercased().contains(search)
            }
        }
        guard sortable else { return filtered }
        return filtered.sorted(using: sortComparator)
    }
    
    private var sortComparator: KeyPathComparator<MovieDetail> {
        switch orderProperty {
        case .title: KeyPathComparator(\.metadata.title, order: order)
        case .releaseDate: KeyPathComparator(\.metadata.releaseDate, order: order)
        case .createdAt: KeyPathComparator(\.metrics.createdAt, order: order)
        case .watchedAt: KeyPathComparator(\.metrics.watchedAt, order: order)
        case .popularity: KeyPathComparator(\.metadata.popularity, order: order)
        }
    }
    
    var body: some View {
        MainView()
            .frame(minWidth: Portrait.width())
            .safeAreaPadding()
            .focusEffect()
            .toolbar{ ToolbarItems() }
            .searchable(text: $searchText)
    }
}

extension MovieListView {
    
    @ViewBuilder
    func MainView() -> some View {
        GeometryReader { proxy in
            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading) {
                    ForEach(filteredMovies) { movie in
                        NavigationLink {
                            MovieDetailView(movie: movie)
                                .navigationTitle(movie.metadata.title)
                        } label: {
                            MovieCard(movie: movie, width: Portrait.width())
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .scrollIndicators(.never, axes: .vertical)
            .onChange(of: proxy.size.width, initial: true) { _, newValue in
                columns = Array(repeating: .init(.fixed(Portrait.width()), alignment: .top),
                                count: Int(newValue / Portrait.width()))
            }
        }
    }
}

// MARK: Toolbar

extension MovieListView {
    
    @ToolbarContentBuilder
    func ToolbarItems() -> some ToolbarContent {
        ToolbarItemGroup {
            Menu("Action", systemImage: "ellipsis.circle") {
                if sortable {
                    Menu("Sort By") {
                        Group {
                            Picker("", selection: $orderProperty) {
                                ForEach(MovieOrderProperty.allCases) { order in
                                    Text(order.localizedKey).tag(order)
                                }
                            }

                            Picker("", selection: $order) {
                                Text("Ascending").tag(SortOrder.forward)
                                Text("Descending").tag(SortOrder.reverse)
                            }
                            
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                }
            }
        }
    }
}

#Preview {
    MovieListView()
}
