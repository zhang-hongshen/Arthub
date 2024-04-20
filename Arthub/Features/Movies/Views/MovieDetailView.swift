//
//  MovieDetailView.swift
//  Arthub
//
//  Created by 张鸿燊 on 31/1/2024.
//

import SwiftUI
import MediaPlayer
import OrderedCollections
import TMDb


struct MovieDetailView: View {
    
    @State var movie: MovieDetail
    @State private var fetchDataTask: Task<Void, Error>? = nil
    @State private var setupPlayerTask: Task<Void, Error>? = nil
    @State private var playerPresented: Bool = false
    @State private var profileSize: CGSize = .init(width: Portrait.width(),
                                                   height: Portrait.width() / Portrait.aspectRatio)
    @State private var sheetPreseted = false
    
    @Environment(\.openURL) private var openURL
    @Environment(ArthubVideoPlayer.self) private var player: ArthubVideoPlayer
    
    private var groudedCrew: OrderedDictionary<String, [CrewMember]> {
        var res: OrderedDictionary<String, [CrewMember]> = [:]
        for crewMember in movie.crew {
            res.updateValue(forKey: crewMember.department, default: []) { $0.append(crewMember) }
        }
        return res
    }
    
    var body: some View {
        MainView()
            .frame(minWidth: 400)
            .toolbar { ToolbarItems() }
            .sheet(isPresented: $sheetPreseted) {
                MovieMetadataSearchView(movie: movie)
            }
            .task{ fetchData() }
            .onAppear(perform: appear)
            .refreshable{ fetchData() }
            .navigationDestination(isPresented: $playerPresented) {
                MoviePlayerView(metrics: movie.metrics)
                    .navigationTitle(movie.metadata.title)
            }
            .onDisappear(perform: disappear)
    }
}

extension MovieDetailView {
    
    @ViewBuilder
    func MainView() -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ScrollView {
                ImageLoader(url: movie.metadata.backdropPath, aspectRatio: Landscape.aspectRatio)
                    .frame(width: width)
                    .clipped()
                    .overlay(alignment: .bottomLeading) {
                        ZStack(alignment: .bottomLeading) {
                            BackdropOverlayView()
                            
                            Color.accent
                                .frame(width: width * movie.progress,
                                       height: Default.cornerRadius)
                        }
                    }
                    
                DetailView()
            }
        }
    }
}

// MARK: Toolbar

extension MovieDetailView {
    
    @ToolbarContentBuilder
    func ToolbarItems() -> some ToolbarContent {
        ToolbarItemGroup {
            Button("Refresh", systemImage: "arrow.clockwise", action: { fetchData() })
            Menu("Action", systemImage: "ellipsis.circle") {
                Button("Edit Metadata", systemImage: "square.and.pencil", action: { sheetPreseted = true})
                
                ShareLink(item: movie.fileURL,
                          subject: Text(verbatim: movie.metadata.title),
                          message: Text(verbatim: movie.metadata.overview ?? "" )) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
    }
}

// MARK: Backdrop Overlay

extension MovieDetailView {
    
    @ViewBuilder
    func BackdropOverlayView() -> some View {
        VStack(alignment: .leading) {
            let logo = movie.logos.first
            ImageLoader(url: logo?.filePath, aspectRatio: CGFloat(logo?.aspectRatio ?? Float(Landscape.aspectRatio))) {
                EmptyView()
            }.frame(height: CGFloat(logo?.height ?? 50))
            
            VStack(alignment: .leading) {
                
                Text(verbatim: movie.metadata.title)
                    .font(.largeTitle.bold())
                    
                
                HStack(alignment: .center) {
                    if let voteAverage = movie.metadata.voteAverage {
                        Rating(value: voteAverage, total: 10)
                            .frame(height: 15)
                    }
                    
                    if let releaseDate = movie.metadata.releaseDate {
                        Text(releaseDate.formatted(.dateTime.day().month().year()))
                    }
                    
                    var runtime : TimeInterval {
                        guard let runtime = movie.metadata.runtime else {
                            return movie.duration
                        }
                        return TimeInterval(runtime * 60)
                    }
                    
                    Text(runtime.formatted(unitsStyle: .full, zeroFormattingBehavior: .dropAll))
                    
                    if let genres = movie.metadata.genres {
                        Text(genres.map{ $0.name }.joined(separator: ","))
                    }
                    
                }.foregroundStyle(.secondary)
                
                
                if let overview = movie.metadata.overview {
                    Text(overview)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding()
            .transparentEffect()
            
        }
    }
    
}

extension MovieDetailView {
    
    @ViewBuilder
    func DetailView() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            
            VideoPlayButtonView()
            
            CastSectionView()
            
            PostersSectionView()
            
            BackdropsSectionView()
            
            CrewSectionView()
            
        }
        .focusEffect()
        .safeAreaPadding()
    }
}

// MARK: VideoPlay Button

extension MovieDetailView {
    
    @ViewBuilder
    func VideoPlayButtonView() -> some View {
        HStack {
            Button {
                setupPlayer()
            } label: {
                Label(movie.metrics.currentTime == 0 ? "Play" : "Resume",
                      systemImage: "play.fill")
                    .padding()
                    .font(.title)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accent)
        }
        
    }
}

// MARK: Cast Section

extension MovieDetailView {
    @ViewBuilder
    func CastSectionView() -> some View {
        Section {
            CastView()
        } header: {
            Text("Top Cast")
                .font(.title.bold())
        }
    }
    
    @ViewBuilder
    func CastView() -> some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top) {
                ForEach(movie.cast.sorted(using: KeyPathComparator(\.order))) { castMember in
                    NavigationLink {
                        PersonDetailView(person: PersonDetail(metadata: Person(
                            id: castMember.id,
                            name: castMember.name,
                            gender: Gender.unknown)))
                    } label: {
                        CastMemberCard(castMember: castMember)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .scrollIndicators(.automatic)
    }
    
    @ViewBuilder
    func CastMemberCard(castMember: CastMember) -> some View {
        VStack(alignment: .leading) {
            ImageLoader(url: castMember.profilePath, aspectRatio: Portrait.aspectRatio) {
                DefaultAvatarView()
            }
            .frame(width: Portrait.width(.small),
                   height: Portrait.width(.small) / Portrait.aspectRatio)
            .clipped()
            .cornerRadius()
            
            Group {
                Text(castMember.name).font(.headline)
                Text(castMember.character).font(.subheadline)
            }
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            
            
        }
        .frame(width: Portrait.width(.small))
    }
    
}

// MARK: Crew Section

extension MovieDetailView {
    @ViewBuilder
    func CrewSectionView() -> some View {
        Section {
            CrewView()
        } header: {
            Text("Crew")
                .font(.title.bold())
        }
    }
    
    @ViewBuilder
    func CrewView() -> some View {
        ForEach(groudedCrew.elements, id: \.key) { (groupName, crew) in
            Section {
                ScrollView(.horizontal) {
                    HStack(alignment: .top) {
                        ForEach(crew, id:\.creditID) { crewMember in
                            NavigationLink {
                                PersonDetailView(person: PersonDetail(metadata: Person(
                                    id: crewMember.id,
                                    name: crewMember.name,
                                    gender: Gender.unknown)))
                            } label: {
                                CrewMemberCardView(crewMember: crewMember)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .scrollIndicators(.automatic)
            } header: {
                Text(groupName)
                    .font(.title2.bold())
            }
        }
    }
    
    @ViewBuilder
    func CrewMemberCardView(crewMember: CrewMember) -> some View {
        VStack(alignment: .leading) {
            ImageLoader(url: crewMember.profilePath, aspectRatio: Portrait.aspectRatio) {
                ImageButton(systemImage: "movieclapper")
            }
            .frame(width: Portrait.width(.small),
                   height: Portrait.width(.small) / Portrait.aspectRatio)
            .clipped()
            .cornerRadius()
            
            Group {
                Text(crewMember.name).font(.headline)
                Text(crewMember.job).font(.subheadline)
            }
            .lineLimit(2)
            .multilineTextAlignment(.leading)
        }
        .frame(width: Portrait.width(.small))
    }
}

// MARK: Posters Section

extension MovieDetailView {

    @ViewBuilder
    func PostersSectionView() -> some View {
        
        Section {
            PostersView()
        } header: {
            Text("Posters")
                .font(.title.bold())
        }
    }
    
    @ViewBuilder
    func PostersView() -> some View {
        ScrollView(.horizontal) {
            HStack(alignment: .center) {
                ForEach(movie.posters) { poster in
                    ImageLoader(url: poster.filePath, aspectRatio: CGFloat(poster.aspectRatio))
                        .frame(height: Portrait.height(.small))
                        .cornerRadius()
                }
            }
        }
        .scrollIndicators(.automatic)
    }
}

// MARK: Backdrops Section

extension MovieDetailView {
    
    @ViewBuilder
    func BackdropsSectionView() -> some View {
        Section {
            BackdropsView()
        } header: {
            Text("Backdrops")
                .font(.title.bold())
        }
    }
    
    
    @ViewBuilder
    func BackdropsView() -> some View {
        ScrollView(.horizontal) {
            HStack(alignment: .center) {
                ForEach(movie.backdrops) { backdrop in
                    ImageLoader(url: backdrop.filePath, aspectRatio: CGFloat(backdrop.aspectRatio))
                        .frame(height: Landscape.height(.small))
                        .cornerRadius()
                }
            }
        }
        .scrollIndicators(.automatic)
    }
}


extension MovieDetailView {
    
    func fetchData() {
        fetchDataTask = Task {
            try await movie.fetchRelatedData()
        }
    }
    
    func appear() {
    }
    
    func setupPlayer() {
        setupPlayerTask = Task {
            var artwork: MPMediaItemArtwork? = nil
            if let cover = movie.metadata.posterPath {
                artwork = await MPMediaItemArtwork(contentsOf: cover)
            }
            let metadata = NowPlayableStaticMetadata(
                id: NSNumber(value: movie.id.hashValue),
                assetURL: movie.fileURL, mediaType: .video,
                isLiveStream: false,
                title: movie.metadata.title,
                artwork: artwork)
            player.preloadItems(playableAssets: [metadata])
            playerPresented = true
        }
    }
    
    func disappear() {
        fetchDataTask?.cancel()
        setupPlayerTask?.cancel()
    }
}
