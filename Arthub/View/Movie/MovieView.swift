//
//  MovieView.swift
//  Arthub
//
//  Created by 张鸿燊 on 31/1/2024.
//

import SwiftUI
import SwiftData
import TMDb

struct MovieView: View {
    @Environment(\.modelContext) private var modelContext
    
    @State private var movies: [MovieDetail] = []
    // toolbar
    @State private var searchKeyword: String = ""
    @State private var selectedOrderProperty: MovieOrderProperty = .title
    @State private var selectedGroup: MovieGroup = .none
    @State private var selectedOrder: SortOrder = .forward
    
    @State private var idealCardWidth: CGFloat = 180
    @State private var detailPresented: Bool = false
    @State private var dropTrageted: Bool = false
    @AppStorage(UserDefaults.localMovieData)
    private var movieData: [String] = [Storage.defaultLocalMovieData]
    
    private var groupedMovies: [(key: String, value: [MovieDetail])] {
        var res: [(key: String, value: [MovieDetail])] = []
        for movie in movies {
            var key: String {
                switch selectedGroup {
                case .none: return ""
                case .releaseYear:
                    if let releaseDate = movie.metadata.releaseDate{
                        return Calendar.current
                            .component(.year, from: releaseDate)
                            .description
                    } else {
                        return ""
                    }
                }
            }
            if let index = res.firstIndex(where: { $0.key == key }) {
                res[index].value.append(movie)
            } else {
                res.append((key: key, value: [movie]))
            }
        }
        for index in res.indices {
            res[index].value.sort(using: sortComparator)
        }

        res.sort {
            switch selectedOrder {
                case .forward: return $0.0 < $1.0
                case .reverse: return $0.0 > $1.0
            }
        }
        return res
    }
    
    @State private var selectedMovieID: UUID? = nil
    
    private var selectedMovie: MovieDetail? {
        return movies.first(where: { $0.id == selectedMovieID })
    }
    
    private var defaultSelectedMovieID: UUID? {
        return groupedMovies.first?.value.first?.id
    }
    
    private var nextSelectedMovieID: UUID? {
        var keyIndex: Int? = nil, valueIndex: Int? = nil
        outerLoop: for i in 0..<groupedMovies.count {
            for j in 0..<groupedMovies[i].value.count {
                if groupedMovies[i].value[j].id == selectedMovieID {
                    keyIndex = i
                    valueIndex = j
                    break outerLoop
                }
            }
        }
        guard let keyIndex = keyIndex, let valueIndex = valueIndex else {
            return defaultSelectedMovieID
        }
        let nextValueIndex = valueIndex + 1
        if nextValueIndex < groupedMovies[keyIndex].value.count {
            return groupedMovies[keyIndex].value[nextValueIndex].id
        }
        let nextKeyIndex = ( keyIndex + 1 ) % groupedMovies.count
        return groupedMovies[nextKeyIndex].value.first?.id
    }
    
    private var preSelectedMovieID: UUID? {
        var keyIndex: Int? = nil, valueIndex: Int? = nil
        outerLoop: for i in 0..<groupedMovies.count {
            for j in 0..<groupedMovies[i].value.count {
                if groupedMovies[i].value[j].id == selectedMovieID {
                    keyIndex = i
                    valueIndex = j
                    break outerLoop
                }
            }
        }
        guard let keyIndex = keyIndex, let valueIndex = valueIndex else {
            return defaultSelectedMovieID
        }
        let preValueIndex = valueIndex - 1
        if preValueIndex >= 0 {
            return groupedMovies[keyIndex].value[preValueIndex].id
        }
        let preKeyIndex = ( keyIndex - 1 + groupedMovies.count) % groupedMovies.count
        return groupedMovies[preKeyIndex].value.last?.id
    }
    
    
    private var sortComparator: KeyPathComparator<MovieDetail> {
        switch selectedOrderProperty {
        case .title: KeyPathComparator(\MovieDetail.metadata.title, order: selectedOrder)
        case .releaseDate: KeyPathComparator(\MovieDetail.metadata.releaseDate, order: selectedOrder)
        case .createdAt: KeyPathComparator(\MovieDetail.metrics.createdAt, order: selectedOrder)
        case .watchedAt: KeyPathComparator(\MovieDetail.metrics.watchedAt, order: selectedOrder)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            MainView()
                .frame(minWidth: idealCardWidth)
                .focusable()
                .focusEffectDisabled()
                .animation(.smooth, value: sortComparator)
                .animation(.spring, value: selectedGroup)
                .onKeyPress(.leftArrow) {
                    self.selectedMovieID = self.preSelectedMovieID
                    return .handled
                }
                .onKeyPress(.rightArrow) {
                    self.selectedMovieID = self.nextSelectedMovieID
                    return .handled
                }
        }
        .safeAreaPadding(10)
        .searchable(text: $searchKeyword)
        .toolbar {
            ToolbarItemGroup {
                ToolbarView()
            }
        }
        .navigationTitle("sidebar.movie")
        .navigationDestination(isPresented: $detailPresented){
            if let movie = selectedMovie {
                MovieDetailView(movie: movie)
            }
        }
        .dropDestination(for: URL.self, action: { urls, _ in
            if !dropTrageted || urls.isEmpty {
                return false
            }
            return dropAction(urls: urls)
        }, isTargeted: { targeted in
            dropTrageted = targeted
        })
        .task(priority: .userInitiated) {
            var urls: [URL] = []
            movieData.forEach { data in
                if let url = URL(string: data) {
                    urls.append(url)
                }
            }
            do {
                try await fetchMovies(urls: urls)
            } catch {
                print("fetchMovies error, \(error)")
            }
        }
    }
}

extension MovieView {
    
    @ViewBuilder
    func ToolbarView() -> some View {
        Menu {
            Group {
                
                Picker("", selection: $selectedGroup) {
                    Text("common.none").tag(MovieGroup.none)
                    Text("movie.releaseYear").tag(MovieGroup.releaseYear)
                }
                Picker("", selection: $selectedOrderProperty) {
                    Text("movie.title").tag(MovieOrderProperty.title)
                    Text("movie.releaseDate").tag(MovieOrderProperty.releaseDate)
                    Text("movie.createdAt").tag(MovieOrderProperty.createdAt)
                    Text("movie.watchedAt").tag(MovieOrderProperty.watchedAt)
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
    }
}


extension MovieView {
    
    @ViewBuilder
    func MainView() -> some View {
        
        GeometryReader { proxy in
            let column = Int(proxy.size.width / idealCardWidth)
            let columns: [GridItem] = Array(
                repeating: .init(.fixed(idealCardWidth), alignment: .top),
                count: column)
            
            ScrollView {
                LazyVStack(alignment: .leading) {
                    LazyVGrid(columns: columns,
                              alignment: .leading) {
                        ForEach(groupedMovies, id: \.key) { (groupName, movies) in
                            Section {
                                ForEach(movies) { movie in
                                    let selected = selectedMovieID == movie.id
                                    MovieCardView(movie: movie, frameWidth: idealCardWidth).tag(movie.id)
                                        .scaleEffect(selected)
                                        .onTapGesture(count: 1) {
                                            selectedMovieID =  movie.id
                                        }
                                        .simultaneousGesture(
                                            TapGesture(count: 2)
                                                .onEnded {
                                                    detailPresented = true
                                                }
                                        )
                                        
                                }
                            } header: {
                                Text(verbatim: groupName)
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                            }
                        }
                    }
                }
            }
            .scrollIndicators(.never)
        }
    }
}

extension MovieView {
    
    func fetchMovies(urls: [URL]) async throws {
        let imagesConfiguration = try await ConfigurationService.shared.getImageConfiguration()
        for movieDataURL in urls {
            let movieFolderURLs = try FileManager.default
                .contentsOfDirectory(at: movieDataURL,
                                     includingPropertiesForKeys: [.isDirectoryKey],
                                     options: [.skipsHiddenFiles])
            for movieFolderURL in movieFolderURLs {
                if let matches = movieFolderURL.fileName.wholeMatch(of: RegexPattern.movieName) {
                    let title = String(matches.output.title)
                    let year = Int(matches.output.year)
                    let movieDetail = try await searchMovieMetadata(title: title, year: year)
                    movieDetail.metadata = movieDetail.metadata.copy(
                        posterPath: imagesConfiguration.posterURL(for: movieDetail.metadata.posterPath),
                        backdropPath: imagesConfiguration.backdropURL(for: movieDetail.metadata.backdropPath)
                    )
                    try FileManager.default
                        .contentsOfDirectory(at: movieFolderURL,
                                             includingPropertiesForKeys: [.isRegularFileKey],
                                             options: [.skipsHiddenFiles])
                        .forEach { url in
                            if nil == url.fileName.lowercased().prefixMatch(of: RegexPattern.movieName) {
                                return
                            }
                            if !url.isVideo {
                                return
                            }
                            movieDetail.urls.append(url)
                        }
                    movies.append(movieDetail)
                }
            }
        }
    }
    
    func searchMovieMetadata(title: String, year: Int?) async throws -> MovieDetail{
        let movieDetail = MovieDetail(
            metadata: Movie(id: 0, title: title, releaseDate: Calendar.current.date(from: DateComponents(year: year))),
            metrics: MovieMetrics())
        let movieMetaList = try await SearchService.shared.searchMovies(query: title, year: year)
        if let metadata = movieMetaList.results.first {
            movieDetail.metadata = metadata
            try await movieDetail.fetchDetail()
            let res = try modelContext.fetch(FetchDescriptor<MovieMetrics>(
                predicate: #Predicate { movie in
                    if let tmdbID = movie.tmdbID {
                        return tmdbID == metadata.id
                    } else {
                        return false
                    }
                },
                sortBy: []
            ))
            if let tmp = res.first {
                movieDetail.metrics = tmp
            } else {
                movieDetail.metrics = MovieMetrics(tmdbID: metadata.id)
                modelContext.insert(movieDetail.metrics)
            }
        }
        return movieDetail
    }
}

extension MovieView {
    
    func dropAction(urls: [URL]) -> Bool{
        let fileManager = FileManager.default
        @AppStorage(UserDefaults.localMovieData)
        var movieDataFolder: [String] = [Storage.defaultLocalMovieData]
        guard let movieDataFolder = movieDataFolder.first, 
                let movieDataURL = URL(string: movieDataFolder) else {
            return false
        }
        if !fileManager.fileExists(atPath: movieDataURL.relativePath, isDirectory: nil) {
            do {
                try fileManager.createDirectory(at: movieDataURL, withIntermediateDirectories: true)
            } catch {
                print("create directory error, \(error)")
                return false
            }
        }
//        for url in urls {
//            if !url.isVideo() {
//                continue
//            }
//            let filename = url.deletingPathExtension().lastPathComponent
//            let dest = movieDataURL.appending(component: filename).appendingPathExtension(url.pathExtension)
//            do {
//                try fileManager.copyItem(at: url, to: dest)
//                let movie = Movie(title: filename, url: dest.relativeString)
//                modelContext.insert(movie)
//            } catch  {
//                print("copyItem error, src \(url.relativeString), dest \(dest.relativeString), \(error)")
//            }
//        }
        return true
    }
}


#Preview {
    MovieView()
        .frame(width: 800, height: 800)
        .modelContainer(for: MovieMetrics.self, inMemory: true)
}
