//
//  TVShowDetailView.swift
//  Arthub
//
//  Created by 张鸿燊 on 28/2/2024.
//

import SwiftUI
import TMDb

struct TVShowDetailView: View {
    
    var tvShow: TVShowDetail
    
    @State private var fetchDataTask: Task<Void, Error>? = nil
    
    var body: some View {
        MainView()
            .toolbar{ ToolbarItems() }
            .task{ fetchData() }
            .refreshable{ fetchData() }
            .onDisappear(perform: fetchDataTask?.cancel)
    }
}


extension TVShowDetailView {
    
    @ViewBuilder
    func MainView() -> some View{
        GeometryReader { proxy in
            ScrollView {
                ImageLoader(url: tvShow.metadata.backdropPath, aspectRatio: Landscape.aspectRatio)
                    .frame(width: proxy.size.width)
                    .clipped()
                    .overlay(alignment: .bottomLeading) {
                        VStack(alignment: .leading) {
                            BackdropOverlayView().transparentEffect()
                            
                            Color.accent
                                .frame(width: proxy.size.width * tvShow.progress,
                                       height: Default.cornerRadius)
                        }
                        
                    }
                
                DetailView()
                    .safeAreaPadding()
            }
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

// MARK: Backdrop Overlay

extension TVShowDetailView {
    
    @ViewBuilder
    func BackdropOverlayView() -> some View {
        VStack(alignment: .leading) {
            
            Text(verbatim: tvShow.metadata.name)
                .font(.largeTitle.bold())
            
            HStack(alignment: .center) {
                if let voteAverage = tvShow.metadata.voteAverage {
                    Rating(value: voteAverage, total: 10)
                        .frame(height: 20)
                }
                
                if let firstAirDate = tvShow.metadata.firstAirDate {
                    Text(firstAirDate.formatted(.dateTime.day().month().year()))
                }
                
                Text(tvShow.duration.formatted(unitsStyle: .full, zeroFormattingBehavior: .dropAll))
                
                if let adultOnly = tvShow.metadata.isAdultOnly, adultOnly {
                    Text(verbatim: "18+").border(.primary)
                }
                
                if let genres = tvShow.metadata.genres {
                    Text(genres.map { $0.name }.joined(separator: ","))
                }
            }.fontWeight(.semibold)
            
            Text(tvShow.metadata.overview ?? "").font(.body)
        }
        .padding()
    }
    
}

// MARK: Detail

extension TVShowDetailView {
    @ViewBuilder
    func DetailView() -> some View {
        VStack(alignment: .leading){
            CastSectionView()
            SeasonsSectionView()
        }
    }
}

// MARK: Cast Section

extension TVShowDetailView {
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
                ForEach(tvShow.cast.sorted(using: KeyPathComparator(\.order))) { castMember in
                    NavigationLink {
                        PersonDetailView(person: PersonDetail(metadata: Person(
                            id: castMember.id,
                            name: castMember.name,
                            gender: Gender.unknown
                        ))).navigationTitle(castMember.name)
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
    }
    
}

// MARK: Seasons Section

extension TVShowDetailView {
    @ViewBuilder
    func SeasonsSectionView() -> some View {
        Section {
            SeasonsView()
        } header: {
            Text("Seasons")
                .font(.title.bold())
        }
    }
    
    @ViewBuilder
    func SeasonsView() -> some View {
        let sortComparator = KeyPathComparator(\TVSeasonDetail.metadata.seasonNumber, order: .forward)
        ForEach(tvShow.seasons.sorted(using: sortComparator)) { season in
            NavigationLink {
                TVSeasonDetailView(season: season)
                    .navigationTitle(tvShow.metadata.name)
                    #if os(macOS)
                    .navigationSubtitle("Season \(season.metadata.seasonNumber)")
                    #endif
            } label: {
                TVSeasonCardView(season: season, height: Landscape.height())
            }
            .buttonStyle(.borderless)
        }
        
    }
}


extension TVShowDetailView {
    
    func fetchData() {
        fetchDataTask = Task {
            try await tvShow.fetchRelatedData()
        }
    }
}
