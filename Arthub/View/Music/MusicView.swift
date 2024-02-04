//
//  MusicView.swift
//  shelf
//
//  Created by 张鸿燊 on 31/1/2024.
//

import SwiftUI
import SwiftData

enum ViewLayout: String, CaseIterable, Identifiable {
    case grid, list
    var id: Self { self }
}

enum MusicOrder: String, CaseIterable, Identifiable {
    case name, releaseYear, createdAt
    var id: Self { self }
}

enum MusicGroup: String, CaseIterable, Identifiable {
    case none, releaseYear
    var id: Self { self }
}

struct MusicView: View {
    @Binding var columnVisibility: NavigationSplitViewVisibility
    
    @Query private var musicList: [Music] = Music.examples()
    
    // toolbar
    @State private var selectedLayout: ViewLayout = .grid
    @State private var selectedOrder: MusicOrder = .createdAt
    @State private var selectedGroup: MusicGroup = .none
    @State private var inspectorPresented: Bool = false
    
    @State private var inspectorSize: CGSize = .zero
    @State private var idealCardWidth: CGFloat = 180
    @State private var cardSpacing: CGFloat = 40
    
    @State private var selectedIndex: Int? = nil;
    @State private var playerPresented: Bool = false
    @State private var dropTrageted: Bool = false
    
    var body: some View {
        ZStack {
            MainView()
            .opacity(playerPresented ? 0 : 1)
            .frame(minWidth: idealCardWidth + inspectorSize.width)
            .overlay {
                if let i = selectedIndex, i >= 0, i < musicList.count, playerPresented {
                    MusicPlayerView(presented: $playerPresented, music: musicList[i])
                        .animation(.easeInOut(duration: 0.5), value: playerPresented)
                } else {
                    EmptyView()
                }
            }
        }
        .navigationTitle("sidebar.music")
        .toolbar {
            if playerPresented{
                ToolbarItem(placement: .navigation) {
                    Button {
                        playerPresented = false;
                    } label: {
                        Label("toolbar.back", systemImage: "chevron.backward")
                    }
                }
            } else {
                ToolbarItemGroup {
                    ToolbarView()
                }
            }
        }
        .onChange(of: playerPresented, initial: false) {
            if playerPresented {
                columnVisibility = .detailOnly
            }
        }
    }
}

extension MusicView {
    
    @ViewBuilder
    func ToolbarView() -> some View {
        Picker("toolbar.layout", selection: $selectedLayout) {
            Label("toolbar.layout.grid", systemImage: "square.grid.2x2").tag(ViewLayout.grid)
            Label("toolbar.layout.list", systemImage: "list.bullet").tag(ViewLayout.list)
        }
        .pickerStyle(.segmented)
        
        Menu {
            Picker("toolbar.group", selection: $selectedGroup) {
                Text("none").tag(MusicGroup.none)
                Text("music.releaseYear").tag(MusicGroup.releaseYear)
            }
            Picker("toolbar.order", selection: $selectedOrder) {
                Text("music.name").tag(MusicOrder.name)
                Text("music.releaseYear").tag(MusicOrder.releaseYear)
                Text("music.createdAt").tag(MusicOrder.createdAt)
            }
        } label: {
            Image(systemName: "square.grid.3x1.below.line.grid.1x2")
        }
        
        Button("toolbar.showInspector", systemImage: "sidebar.right") {
            inspectorPresented.toggle()
        }
    }
}

extension MusicView {

    @ViewBuilder
    func MainView() -> some View {
        GeometryReader { proxy in
            let usableWidth = proxy.size.width - inspectorSize.width
            var column: Int {
                switch selectedLayout {
                case .grid:
                    Int(usableWidth / (idealCardWidth + cardSpacing))
                case .list:
                    1
                }
            }
            let cardWidth: CGFloat = usableWidth / CGFloat(column) - cardSpacing
            let columns: [GridItem] = Array(repeating: .init(.fixed(cardWidth), alignment: .top), count: column)

            List(selection: $selectedIndex) {
                LazyVGrid(columns: columns, alignment: .leading, spacing: cardSpacing) {
                    ForEach(musicList.indices) { i in
                        let selected = selectedIndex == i
                        Group {
                            switch selectedLayout {
                            case.grid:
                                MusicCardView(music: musicList[i], frameWidth: cardWidth)
                            case.list:
                                MusicListView(music: musicList[i])
                            }
                        }
                        .tag(i)
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
            .inspector(isPresented: $inspectorPresented) {
                InspectorView()
            }
            .inspectorColumnWidth(inspectorSize.width)
            .onDrop(of: [.movie, .audio], isTargeted: $dropTrageted) { items, position in
                debugPrint("location \(position)")
                for item in items {
                    debugPrint(item)
                }
                return true
            }
        }
        
    }
    
    @ViewBuilder
    func InspectorView() -> some View {
        Group {
            if let i = selectedIndex, i >= 0, i < musicList.count {
                MusicInspectorView(music: musicList[i])
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

#Preview {
    MusicView(columnVisibility: .constant(.all))
}
