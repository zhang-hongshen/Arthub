//
//  TVShowDetailView.swift
//  Arthub
//
//  Created by 张鸿燊 on 28/2/2024.
//

import SwiftUI
import TMDb
import MediaPlayer

struct TVShowDetailView: View {

    var tvShow: TVShowDetail

    @State private var fetchDataTask: Task<Void, Error>? = nil
    @State private var setupPlayerTask: Task<Void, Error>? = nil
    @State private var playerPresented: Bool = false
    @State private var playerStartIndex: Int = 0
    @State private var selectedSeasonNumber: Int? = nil

    @Environment(ArthubVideoPlayer.self) private var player

    private var seasons: [TVSeasonDetail] {
        tvShow.seasons.sorted(using: KeyPathComparator(\.metadata.seasonNumber, order: .forward))
    }

    /// Flattened episode list across all seasons, for "continue watching".
    private var episodes: [TVEpisodeDetail] {
        seasons.flatMap { season in
            season.episodes.filter(\.isAvailable).sorted(using: KeyPathComparator(\.metadata.episodeNumber,
                                                                                  order: .forward))
        }
    }

    private var lastWatchingEpisode: TVEpisodeDetail? {
        episodes.filter { $0.metrics.watchedAt != nil }
            .sorted(using: KeyPathComparator(\.metrics.watchedAt, order: .reverse))
            .first
    }

    /// The episode the Play button starts: the last watched one, or the very first.
    private var upNextEpisode: TVEpisodeDetail? {
        lastWatchingEpisode ?? episodes.first
    }

    private var selectedSeason: TVSeasonDetail? {
        seasons.first { $0.metadata.seasonNumber == selectedSeasonNumber }
            ?? seasons.first { $0.metadata.seasonNumber == upNextEpisode?.metadata.seasonNumber }
            ?? seasons.first
    }

    var body: some View {
        MainView()
            .frame(minWidth: 400)
            .toolbar{ ToolbarItems() }
            .task{ fetchData() }
            .task(id: selectedSeason?.id) { await fetchSeasonDetail() }
            .refreshable{ fetchData() }
            .navigationDestination(isPresented: $playerPresented) {
                TVShowPlayerView(playlist: episodes, startAtIndex: playerStartIndex)
            }
            .onDisappear {
                fetchDataTask?.cancel()
                setupPlayerTask?.cancel()
            }
    }
}


extension TVShowDetailView {
    
    @ViewBuilder
    func MainView() -> some View {
        MediaDetailPage { size in
            HeroView(size: size)
        } content: {
            EpisodesSectionView()
            CastAndCrewSectionView()
            AboutSectionView()
            InformationSectionView()
        }
    }
    
}

// MARK: Toolbar

extension TVShowDetailView {
    @ToolbarContentBuilder
    func ToolbarItems() -> some ToolbarContent {
        ToolbarItemGroup {
            Button("Refresh", systemImage: "arrow.clockwise", action: { fetchData() })
        }
        
    }
}

// MARK: Hero

extension TVShowDetailView {
    
    /// Creators when TMDb lists them, otherwise the first few executive producers.
    private var creators: [CrewMember] {
        var seen = Set<Int>()
        let creators = tvShow.crew.filter { $0.job == "Creator" }
        let crew = creators.isEmpty ? tvShow.crew.filter { $0.job == "Executive Producer" } : creators
        return Array(crew.filter { seen.insert($0.id).inserted }.prefix(5))
    }
    
    @ViewBuilder
    func HeroView(size: CGSize) -> some View {
        var metadata: [String] {
            var items: [String] = []
            if let genres = tvShow.metadata.genres?.prefix(2), !genres.isEmpty {
                items.append(genres.map(\.name).joined(separator: ", "))
            }
            if let firstAirDate = tvShow.metadata.firstAirDate {
                items.append(firstAirDate.formatted(.dateTime.year()))
            }
            let seasonCount = tvShow.metadata.numberOfSeasons ?? seasons.count
            if seasonCount > 0 {
                items.append(String(localized: "\(seasonCount) Seasons"))
            }
            return items
        }
        var badges: [String] {
            var badges: [String] = []
            if let voteAverage = tvShow.metadata.voteAverage, voteAverage > 0 {
                badges.append("★ " + voteAverage.formatted(.number.precision(.fractionLength(1))))
            }
            if tvShow.metadata.isAdultOnly == true {
                badges.append("18+")
            }
            return badges
        }
        var credits: [(label: LocalizedStringKey, value: String)] {
            var credits: [(label: LocalizedStringKey, value: String)] = []
            let starring = tvShow.cast.sorted(using: KeyPathComparator(\.order)).prefix(3).map(\.name)
            if !starring.isEmpty {
                credits.append(("Starring", starring.joined(separator: ", ")))
            }
            let creatorNames = creators.prefix(2).map(\.name).joined(separator: ", ")
            if creators.first?.job == "Creator" {
                credits.append(("Created By", creatorNames))
            } else if !creatorNames.isEmpty {
                credits.append(("Executive Producers", creatorNames))
            }
            return credits
        }
        
        MediaHeroView(backdropURL: tvShow.metadata.backdropPath,
                      size: size,
                      metadata: metadata,
                      badges: badges,
                      overview: tvShow.metadata.overview,
                      credits: credits) {
            MediaTitleText(title: tvShow.metadata.name)
        } actions: {
            ActionsView()
        }
    }
    
    @ViewBuilder
    func ActionsView() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                guard let episode = upNextEpisode,
                      let index = episodes.firstIndex(where: { $0.id == episode.id }) else { return }
                setupPlayer(from: index)
            } label: {
                if let episode = upNextEpisode {
                    let season = episode.metadata.seasonNumber
                    let number = episode.metadata.episodeNumber
                    if lastWatchingEpisode == nil {
                        Label("Play S\(season), E\(number)", systemImage: "play.fill")
                    } else {
                        Label("Resume S\(season), E\(number)", systemImage: "play.fill")
                    }
                } else {
                    Label("Play", systemImage: "play.fill")
                }
            }
            .buttonStyle(MediaPlayButtonStyle())
            .disabled(upNextEpisode == nil)
            
            if let episode = lastWatchingEpisode {
                MediaRemainingView(progress: episode.progress, duration: episode.duration)
            }
        }
    }
}

// MARK: Episodes Section

extension TVShowDetailView {
    
    @ViewBuilder
    func EpisodesSectionView() -> some View {
        if let season = selectedSeason {
            MediaShelf {
                SeasonTabsView(selected: season)
            } content: {
                ForEach(season.episodes.sorted(using: KeyPathComparator(\.metadata.episodeNumber,
                                                                        order: .forward))) { episode in
                    TVEpisodeCard(episode: episode, width: 300)
                        .onTapGesture {
                            guard episode.isAvailable,
                                  let index = episodes.firstIndex(where: { $0.id == episode.id }) else { return }
                            setupPlayer(from: index)
                        }
                }
            }
        }
    }
    
    /// "Season 1  Season 2  Season 3 ... See All" like the Apple TV season picker.
    @ViewBuilder
    func SeasonTabsView(selected: TVSeasonDetail) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 20) {
            ScrollView(.horizontal) {
                HStack(spacing: 20) {
                    ForEach(seasons) { season in
                        let isSelected = season.id == selected.id
                        Button {
                            selectedSeasonNumber = season.metadata.seasonNumber
                        } label: {
                            Text(season.metadata.seasonNumber == 0
                                 ? String(localized: "Specials")
                                 : String(localized: "Season \(season.metadata.seasonNumber)"))
                                .font(.title2.bold())
                                .foregroundStyle(isSelected ? HierarchicalShapeStyle.primary : .tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
            
            NavigationLink {
                TVSeasonDetailView(season: selected)
                    .navigationTitle(tvShow.metadata.name)
                    #if os(macOS)
                    .navigationSubtitle("Season \(selected.metadata.seasonNumber)")
                    #endif
            } label: {
                Label("See All", systemImage: "chevron.right")
                    .labelStyle(.titleOnly)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: Cast & Crew Section

extension TVShowDetailView {
    
    @ViewBuilder
    func CastAndCrewSectionView() -> some View {
        if !tvShow.cast.isEmpty || !creators.isEmpty {
            MediaShelf("Cast & Crew") {
                ForEach(tvShow.cast.sorted(using: KeyPathComparator(\.order)).prefix(30)) { castMember in
                    NavigationLink {
                        PersonDetailView(person: Person(metadata: TMDb.Person(
                            id: castMember.id,
                            name: castMember.name,
                            gender: Gender.unknown
                        ))).navigationTitle(castMember.name)
                    } label: {
                        MediaPersonCard(name: castMember.name,
                                        role: castMember.character,
                                        profilePath: castMember.profilePath)
                    }
                    .buttonStyle(.plain)
                }
                
                ForEach(creators, id: \.creditID) { crewMember in
                    NavigationLink {
                        PersonDetailView(person: Person(metadata: TMDb.Person(
                            id: crewMember.id,
                            name: crewMember.name,
                            gender: Gender.unknown
                        ))).navigationTitle(crewMember.name)
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

// MARK: About Section

extension TVShowDetailView {
    
    @ViewBuilder
    func AboutSectionView() -> some View {
        if tvShow.metadata.overview?.isEmpty == false || tvShow.metadata.tagline?.isEmpty == false {
            VStack(alignment: .leading, spacing: 14) {
                MediaSectionHeader(title: "About")
                    .padding(.horizontal, MediaDetail.horizontalPadding)
                MediaAboutCard(title: tvShow.metadata.name,
                               subtitle: tvShow.metadata.genres?.map(\.name).joined(separator: ", "),
                               tagline: tvShow.metadata.tagline,
                               overview: tvShow.metadata.overview)
            }
        }
    }
}

// MARK: Information Section

extension TVShowDetailView {
    
    private var informationItems: [MediaInfoItem] {
        let metadata = tvShow.metadata
        var items: [MediaInfoItem] = []
        items.append("First Aired", metadata.firstAirDate?.formatted(date: .long, time: .omitted))
        items.append("Last Aired", metadata.lastAirDate?.formatted(date: .long, time: .omitted))
        if let numberOfEpisodes = metadata.numberOfEpisodes {
            items.append("Episodes", numberOfEpisodes.formatted())
        }
        if tvShow.duration > 0 {
            items.append("Run Time", MediaDetail.runtime(tvShow.duration))
        }
        items.append("Network", metadata.networks?.map(\.name).joined(separator: ", "))
        items.append("Status", metadata.status)
        items.append("Region of Origin", metadata.originCountry?.map(MediaDetail.regionName).joined(separator: ", "))
        items.append("Original Audio", MediaDetail.languageName(metadata.originalLanguage))
        items.append("Languages", metadata.languages?.compactMap { MediaDetail.languageName($0) }.joined(separator: ", "))
        items.append("Original Title", metadata.originalName == metadata.name ? nil : metadata.originalName)
        items.append("Studio", metadata.productionCompanies?.map(\.name).joined(separator: ", "))
        return items
    }
    
    @ViewBuilder
    func InformationSectionView() -> some View {
        MediaInfoSection(items: informationItems)
    }
}

extension TVShowDetailView {

    func setupPlayer(from index: Int) {
        guard episodes.indices.contains(index) else { return }
        playerStartIndex = index
        setupPlayerTask = Task {
            var playableAssets: [NowPlayableStaticMetadata] = []
            for episode in episodes {
                var artwork: MPMediaItemArtwork? = nil
                if let still = episode.metadata.stillPath {
                    artwork = await MPMediaItemArtwork(contentsOf: still)
                }
                playableAssets.append(NowPlayableStaticMetadata(
                    id: NSNumber(value: episode.id),
                    assetURL: episode.fileURL, mediaType: .video,
                    isLiveStream: false, title: episode.metadata.name,
                    artwork: artwork))
            }
            player.preloadItems(playableAssets: playableAssets)
            playerPresented = true
        }
    }
    
    func fetchData() {
        fetchDataTask = Task {
            try await tvShow.fetchRelatedData()
        }
    }
    
    func fetchSeasonDetail() async {
        do { try await selectedSeason?.fetchDetail() }
        catch {}
    }
}
