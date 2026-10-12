//
//  MovieDetailView.swift
//  Arthub
//
//  Created by 张鸿燊 on 31/1/2024.
//

import SwiftUI
import TMDb


struct MovieDetailView: View {
    
    @State var movie: Movie
    @State private var fetchDataTask: Task<Void, Error>? = nil
    @State private var setupPlayerTask: Task<Void, Error>? = nil
    @State private var playerPresented: Bool = false
    @State private var sheetPreseted = false
    
    @Environment(\.openURL) private var openURL
    @Environment(ArthubVideoPlayer.self) private var player: ArthubVideoPlayer
    
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
        MediaDetailPage { size in
            HeroView(size: size)
        } content: {
            CastAndCrewSectionView()
            TrailersSectionView()
            AboutSectionView()
            InformationSectionView()
            BackdropsSectionView()
            PostersSectionView()
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

// MARK: Hero

extension MovieDetailView {
    
    private var runtime: TimeInterval {
        guard let runtime = movie.metadata.runtime, runtime > 0 else {
            return movie.duration
        }
        return TimeInterval(runtime * 60)
    }
    
    private var directors: [CrewMember] {
        movie.crew.filter { $0.job == "Director" }
    }
    
    @ViewBuilder
    func HeroView(size: CGSize) -> some View {
        var metadata: [String] {
            var items: [String] = []
            if let genres = movie.metadata.genres?.prefix(2), !genres.isEmpty {
                items.append(genres.map(\.name).joined(separator: ", "))
            }
            if let releaseDate = movie.metadata.releaseDate {
                items.append(releaseDate.formatted(.dateTime.year()))
            }
            items.append(MediaDetail.runtime(runtime))
            return items
        }
        var badges: [String] {
            var badges: [String] = []
            if let voteAverage = movie.metadata.voteAverage, voteAverage > 0 {
                badges.append("★ " + voteAverage.formatted(.number.precision(.fractionLength(1))))
            }
            if movie.metadata.isAdultOnly == true {
                badges.append("18+")
            }
            return badges
        }
        var credits: [(label: LocalizedStringKey, value: String)] {
            var credits: [(label: LocalizedStringKey, value: String)] = []
            let starring = movie.cast.sorted(using: KeyPathComparator(\.order)).prefix(3).map(\.name)
            if !starring.isEmpty {
                credits.append(("Starring", starring.joined(separator: ", ")))
            }
            if !directors.isEmpty {
                credits.append(("Director", directors.map(\.name).joined(separator: ", ")))
            }
            return credits
        }
        
        MediaHeroView(backdropURL: movie.metadata.backdropPath,
                      size: size,
                      metadata: metadata,
                      badges: badges,
                      overview: movie.metadata.overview,
                      credits: credits) {
            TitleView()
        } actions: {
            ActionsView()
        }
    }
    
    @ViewBuilder
    func TitleView() -> some View {
        if let logo = movie.logos.first {
            ArtworkImage(url: logo.filePath,
                         aspectRatio: CGFloat(logo.aspectRatio),
                         contentMode: .fit) {
                MediaTitleText(title: movie.metadata.title)
            }
            .modifier(MediaLogoModifier())
            .frame(maxWidth: 360, maxHeight: 130, alignment: .bottomLeading)
        } else {
            MediaTitleText(title: movie.metadata.title)
        }
    }
    
    @ViewBuilder
    func ActionsView() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    setupPlayer()
                } label: {
                    Label(movie.metrics.currentTime == 0 ? "Play" : "Resume",
                          systemImage: "play.fill")
                }
                .buttonStyle(MediaPlayButtonStyle())
                .disabled(!movie.isAvailable)
                
                ShareLink(item: movie.fileURL,
                          subject: Text(verbatim: movie.metadata.title),
                          message: Text(verbatim: movie.metadata.overview ?? "" )) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(MediaCircleButtonStyle())
                
                Button("Edit Metadata", systemImage: "square.and.pencil") {
                    sheetPreseted = true
                }
                .buttonStyle(MediaCircleButtonStyle())
            }
            
            if !movie.isAvailable {
                Label("Unavailable", systemImage: "externaldrive.badge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            MediaRemainingView(progress: movie.progress, duration: movie.duration)
        }
    }
}

// MARK: Cast & Crew Section

extension MovieDetailView {
    
    private static let featuredJobs = ["Director", "Screenplay", "Writer", "Novel", "Producer",
                                       "Original Music Composer", "Director of Photography"]
    
    /// Crew members Apple TV puts after the cast: directors, writers, producers, ...
    private var featuredCrew: [CrewMember] {
        var seen = Set<String>()
        return movie.crew
            .filter { Self.featuredJobs.contains($0.job) }
            .sorted { Self.featuredJobs.firstIndex(of: $0.job)! < Self.featuredJobs.firstIndex(of: $1.job)! }
            .filter { seen.insert("\($0.id)-\($0.job)").inserted }
    }
    
    @ViewBuilder
    func CastAndCrewSectionView() -> some View {
        if !movie.cast.isEmpty || !featuredCrew.isEmpty {
            MediaShelf("Cast & Crew") {
                ForEach(movie.cast.sorted(using: KeyPathComparator(\.order)).prefix(30)) { castMember in
                    NavigationLink {
                        PersonDetailView(person: Person(metadata: TMDb.Person(
                            id: castMember.id,
                            name: castMember.name,
                            gender: Gender.unknown)))
                    } label: {
                        MediaPersonCard(name: castMember.name,
                                        role: castMember.character,
                                        profilePath: castMember.profilePath)
                    }
                    .buttonStyle(.plain)
                }
                
                ForEach(featuredCrew, id: \.creditID) { crewMember in
                    NavigationLink {
                        PersonDetailView(person: Person(metadata: TMDb.Person(
                            id: crewMember.id,
                            name: crewMember.name,
                            gender: Gender.unknown)))
                    } label: {
                        MediaPersonCard(name: crewMember.name,
                                        role: crewMember.job,
                                        profilePath: crewMember.profilePath)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: Trailers Section

extension MovieDetailView {
    
    private var youTubeVideos: [VideoMetadata] {
        movie.videos.filter { $0.site == "YouTube" }
    }
    
    @ViewBuilder
    func TrailersSectionView() -> some View {
        if !youTubeVideos.isEmpty {
            MediaShelf("Trailers") {
                ForEach(youTubeVideos) { video in
                    Button {
                        if let url = URL(string: "https://www.youtube.com/watch?v=\(video.key)") {
                            openURL(url)
                        }
                    } label: {
                        TrailerCard(video: video)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    @ViewBuilder
    func TrailerCard(video: VideoMetadata) -> some View {
        let width: CGFloat = 300
        VStack(alignment: .leading, spacing: 6) {
            ArtworkImage(url: URL(string: "https://img.youtube.com/vi/\(video.key)/hqdefault.jpg"),
                         aspectRatio: MediaDetail.stillAspectRatio)
            .frame(width: width, height: width / MediaDetail.stillAspectRatio)
            .clipped()
            .overlay {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow()
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            Text(verbatim: video.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(verbatim: video.type.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: width, alignment: .leading)
    }
}

// MARK: About Section

extension MovieDetailView {
    
    @ViewBuilder
    func AboutSectionView() -> some View {
        if movie.metadata.overview?.isEmpty == false || movie.metadata.tagline?.isEmpty == false {
            VStack(alignment: .leading, spacing: 14) {
                MediaSectionHeader(title: "About")
                    .padding(.horizontal, MediaDetail.horizontalPadding)
                MediaAboutCard(title: movie.metadata.title,
                               subtitle: movie.metadata.genres?.map(\.name).joined(separator: ", "),
                               tagline: movie.metadata.tagline,
                               overview: movie.metadata.overview)
            }
        }
    }
}

// MARK: Information Section

extension MovieDetailView {
    
    private var informationItems: [MediaInfoItem] {
        let metadata = movie.metadata
        var items: [MediaInfoItem] = []
        items.append("Released", metadata.releaseDate?.formatted(date: .long, time: .omitted))
        items.append("Run Time", MediaDetail.runtime(runtime))
        items.append("Region of Origin", metadata.productionCountries?.map(\.name).joined(separator: ", "))
        items.append("Original Audio", MediaDetail.languageName(metadata.originalLanguage))
        items.append("Spoken Languages", metadata.spokenLanguages?.map(\.name).joined(separator: ", "))
        items.append("Original Title", metadata.originalTitle == metadata.title ? nil : metadata.originalTitle)
        items.append("Director", directors.map(\.name).joined(separator: ", "))
        items.append("Studio", metadata.productionCompanies?.map(\.name).joined(separator: ", "))
        items.append("Status", metadata.status?.rawValue)
        if let budget = metadata.budget, budget > 0 {
            items.append("Budget", budget.formatted(.currency(code: "USD").precision(.fractionLength(0))))
        }
        if let revenue = metadata.revenue, revenue > 0 {
            items.append("Box Office", revenue.formatted(.currency(code: "USD").precision(.fractionLength(0))))
        }
        return items
    }
    
    @ViewBuilder
    func InformationSectionView() -> some View {
        MediaInfoSection(items: informationItems)
    }
}

// MARK: Backdrops Section

extension MovieDetailView {
    
    @ViewBuilder
    func BackdropsSectionView() -> some View {
        if !movie.backdrops.isEmpty {
            MediaShelf("Backdrops") {
                ForEach(movie.backdrops) { backdrop in
                    ArtworkImage(url: backdrop.filePath, aspectRatio: CGFloat(backdrop.aspectRatio))
                        .frame(height: Landscape.height(.small) * 1.4)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}

// MARK: Posters Section

extension MovieDetailView {
    
    @ViewBuilder
    func PostersSectionView() -> some View {
        if !movie.posters.isEmpty {
            MediaShelf("Posters") {
                ForEach(movie.posters) { poster in
                    ArtworkImage(url: poster.filePath, aspectRatio: CGFloat(poster.aspectRatio))
                        .frame(height: Portrait.height(.small))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
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
        guard movie.isAvailable else { return }
        setupPlayerTask = Task {
            player.setPlaylist([await movie.playlistItem()])
            playerPresented = true
        }
    }
    
    func disappear() {
        fetchDataTask?.cancel()
        setupPlayerTask?.cancel()
    }
}
