//
//  MovieView.swift
//  shelf
//
//  Created by 张鸿燊 on 31/1/2024.
//

import SwiftUI


enum MovieOrder: String, CaseIterable, Identifiable {
    case name, releaseYear, createdAt
    var id: Self { self }
}

enum MovieGroup: String, CaseIterable, Identifiable {
    case none, releaseYear
    var id: Self { self }
}

struct MovieView: View {

    @Binding var columnVisibility: NavigationSplitViewVisibility
    
    @State private var movies: [Movie] = Movie.examples()
    // toolbar
    @State private var selectedOrder: MovieOrder = .createdAt
    @State private var selectedGroup: MovieGroup = .none
    @State private var inspectorPresented: Bool = false
    
    @State private var inspectorSize: CGSize = .zero
    @State private var idealCardWidth: CGFloat = 180
    @State private var cardSpacing: CGFloat = 20
    
    @State private var selectedIndex: Int? = nil;
    @State private var playerPresented: Bool = false
    @State private var dropTrageted: Bool = false
    
    var body: some View {
        ZStack {
            MainView()
            
            .opacity(playerPresented ? 0 : 1)
            .frame(minWidth: idealCardWidth + inspectorSize.width)
            
            if let i = selectedIndex, i >= 0, i < movies.count, playerPresented {
                MoviePlayerView(presented: $playerPresented, movie: $movies[i])
                    .opacity(playerPresented ? 1 : 0)
                    .animation(.easeInOut(duration: 0.5), value: playerPresented)
            }
        }
        .navigationTitle("sidebar.movie")
        .toolbar(playerPresented ? .hidden : .visible, for: .windowToolbar)
        .toolbar {
            ToolbarItemGroup {
                ToolbarView()
            }
        }
        .onChange(of: playerPresented, initial: false) {
            if playerPresented {
                columnVisibility = .detailOnly
            }
        }
    }
}

extension MovieView {
    
    @ViewBuilder
    func ToolbarView() -> some View {
        Menu {
            Picker("toolbar.group", selection: $selectedGroup) {
                Text("none").tag(MovieGroup.none)
                Text("movie.releaseYear").tag(MovieGroup.releaseYear)
            }
            Picker("toolbar.order", selection: $selectedOrder) {
                Text("movie.name").tag(MovieOrder.name)
                Text("movie.releaseYear").tag(MovieOrder.releaseYear)
                Text("movie.createdAt").tag(MovieOrder.createdAt)
            }
        } label: {
            Image(systemName: "square.grid.3x1.below.line.grid.1x2")
        }
        
        Button("toolbar.showInspector", systemImage: "sidebar.right") {
            inspectorPresented.toggle()
        }
    }
}

extension MovieView {
    
    @ViewBuilder
    func MainView() -> some View {
        
        GeometryReader { proxy in
            
            let usableWidth = proxy.size.width - inspectorSize.width
            let column = Int(usableWidth / (idealCardWidth + cardSpacing))
            let cardWidth: CGFloat = usableWidth / CGFloat(column) - cardSpacing
            let columns: [GridItem] = Array(repeating: .init(.fixed(cardWidth), alignment: .top), count: column)
            
            List(selection: $selectedIndex) {
                LazyVGrid(columns: columns, spacing: cardSpacing) {
                    ForEach(movies.indices) { i in
                        let selected = selectedIndex == i
                        MovieCardView(movie: $movies[i], frameWidth: cardWidth).tag(i)
                            .background {
                                RoundedRectangle(cornerRadius: .defaultCornerRadius)
                                    .fill(selected ? Color.highlightColor.opacity(0.4) : Color.clear)
                            }
                            .tint(selected ? Color.selectedTextColor : Color.textColor)
                            .onTapGesture(count: 1) {
                                selectedIndex = i
                            }
                            .simultaneousGesture(
                                TapGesture(count: 2)
                                    .onEnded {
                                        selectedIndex = i
                                        playerPresented = true
                                    }
                            )
                        
                    }
                }
            }
            .onDropMovie(targeted: $dropTrageted)
            .inspector(isPresented: $inspectorPresented) {
                InspectorView()
            }
            .inspectorColumnWidth(inspectorSize.width)
            
        }
    }
    
    @ViewBuilder
    func InspectorView() -> some View {
        Group {
            if let i = selectedIndex, i >= 0, i < movies.count {
                MovieInspectorView(movie: $movies[i])
            } else {
                Text("inspector.empty").font(.title)
            }
        }
        .overlay {
            GeometryReader { proxy in
                Color.clear
                    .onChange(of: inspectorPresented, initial: false) {
                        inspectorSize = inspectorPresented ? proxy.size : .zero
                    }
            }
        }
    }
    
}

struct DropAction: ViewModifier {
    
    @Binding var trageted: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    
    @State var progressFinished: Double = 0
    
    func body(content: Content) -> some View {
        content.onDrop(of: [.movie], isTargeted: $trageted) { items, position in
            if !trageted || items.isEmpty {
                return false
            }
            debugPrint("123")
            let fileManager = FileManager.default
            guard let appsupportDir = try? fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil, create: true) else {
                return false
            }
            let folderPath = appsupportDir.absoluteString + UserDefaults.LibraryLocation.movie.rawValue
            if !fileManager.fileExists(atPath: folderPath, isDirectory: nil) {
                do {
                    try fileManager.createDirectory(atPath: folderPath, withIntermediateDirectories: true)
                } catch {
                    debugPrint(" err \(error)")
                }
            }
            openWindow(id: "window.progress", value: progressFinished)
            let total = items.count
            let progressPerItem: Double = 1.0 / Double(items.count)
            for i in 0..<total {
                let progress = items[i].loadFileRepresentation(for: .movie) { url, Bool, err in
                    guard let url = url, err == nil else {
                        return
                    }
                    let fileDestPath = folderPath + "\(UUID().uuidString).\(url.pathExtension)"
                    let originalFileName = url.deletingPathExtension().lastPathComponent
                    debugPrint("fileDestPath: \(fileDestPath)")
                    debugPrint("originalFileName: \(originalFileName)")
                    debugPrint("description: \(url.description)")
                    debugPrint("absoluteString: \(url.absoluteString)")
                    do {
                        try fileManager.copyItem(atPath: url.absoluteString, toPath: fileDestPath)
                        let ent = Movie(name: originalFileName, filepath: fileDestPath)
                        context.insert(ent)
                    } catch  {
                        debugPrint(" err \(error)")
                    }
                }
                progressFinished += progressPerItem * progress.fractionCompleted
            }
            return true
        }
    }
}

extension View {
    func onDropMovie(targeted: Binding<Bool>) -> some View {
        self.modifier(DropAction(trageted: targeted))
    }
}


#Preview {
    MovieView(columnVisibility: .constant(NavigationSplitViewVisibility.all))
        .frame(width: 800, height: 800)
}
