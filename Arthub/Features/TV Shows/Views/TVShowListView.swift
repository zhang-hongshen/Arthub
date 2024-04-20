//
//  TVShowListView.swift
//  Arthub
//
//  Created by 张鸿燊 on 8/3/2024.
//

import SwiftUI

struct TVShowListView: View {
    
    @State var tvShows: [TVShowDetail] = []
    @State var sortable = true
    @State private var orderProperty: TVShowOrderProperty = .title
    @State private var order: SortOrder = .forward
    @State private var searchText: String = ""
    @State private var columns: [GridItem] = []
    @State private var idealCardWidth = Portrait.width()
    
    private var filteredTVShows: [TVShowDetail] {
        var filtered: [TVShowDetail] = tvShows
        if !searchText.isEmpty {
            let search = searchText.lowercased()
            filtered = tvShows.filter {
                if let originalName = $0.metadata.originalName,
                    originalName.contains(search) {
                    return true
                }
                return $0.metadata.name.lowercased().contains(search)
            }
        }
        guard sortable else { return filtered }
        return filtered.sorted(using: sortComparator)
    }
    
    private var sortComparator: KeyPathComparator<TVShowDetail> {
        switch orderProperty {
        case .title:
            KeyPathComparator(\.metadata.name, order: order)
        case .popularity:
            KeyPathComparator(\.metadata.popularity, order: order)
        }
    }
    
    var body: some View {
        MainView()
            .frame(minWidth: idealCardWidth)
            .safeAreaPadding()
            .toolbar{ ToolbarItems()}
            .searchable(text: $searchText)
    }
}

// MARK: Toolbar

extension TVShowListView {
    
    @ToolbarContentBuilder
    func ToolbarItems() -> some ToolbarContent {
        ToolbarItemGroup {
            Menu("Action", systemImage: "ellipsis.circle") {
                if sortable {
                    Menu("Sort By") {
                        Group {
                            Picker("", selection: $orderProperty) {
                                ForEach(TVShowOrderProperty.allCases) { order in
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


extension TVShowListView {
    
    @ViewBuilder
    func MainView() -> some View {
        GeometryReader { proxy in
            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading) {
                    ForEach(tvShows) { tvShow in
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
            .scrollIndicators(.never, axes: .vertical)
            
            .onChange(of: proxy.size.width, initial: true) { _, newValue in
                columns = Array(repeating: .init(.fixed(idealCardWidth), alignment: .top),
                                count: Int(newValue / idealCardWidth))
            }
        }
    }
}
    
#Preview {
    TVShowListView()
}
