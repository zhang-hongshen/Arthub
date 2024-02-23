//
//  MovieDetailView.swift
//  Arthub
//
//  Created by 张鸿燊 on 31/1/2024.
//

import SwiftUI
import TMDb

struct MovieDetailView: View {
    
    @State var movie: MovieDetail
    @State private var playerPresented: Bool = false
    @State private var personViewPresented: Bool = false
    @State private var selectedPerson: Person? = nil
    @State private var profileSize: CGSize = .init(width: 150, height: 200)

    private var groudedCrew: [String: [CrewMember]] {
        var res: [String: [CrewMember]] = [:]
        for crewMember in movie.crew {
            let key = crewMember.department
            if res[key] == nil {
                res[key] = []
            }
            res[key]?.append(crewMember)
        }
        return res
    }
    
    var body: some View {
        ScrollView {
            AsyncImage(url: movie.metadata.backdropPath) { phase in
                switch phase {
                case .empty:
                    DefaultImageView()
                case .success(let image):
                    image.resizable()
                case .failure(let error):
                    ErrorImageView(error: error)
                @unknown default:
                    fatalError()
                }
            }
            .frame(height: 500, alignment: .top)
            .overlay {
                GeometryReader { proxy in
                    VStack {
                        Spacer()
                        VStack(alignment: .leading) {
                            BackdropOverlayView()
                                .safeAreaPadding(10)
                            Rectangle()
                                .frame(width: proxy.size.width * movie.metrics.progress,
                                       height: .defaultCornerRadius)
                                .opacity(0.6)
                        }
                    }
                }
            }
            DetailView()
            
        }
        .scrollIndicators(.never, axes: .vertical)
        .navigationTitle(movie.metadata.title)
        .navigationDestination(isPresented: $playerPresented) {
            MoviePlayerView(title: movie.metadata.title,
                            urls: $movie.urls,
                            metrics: $movie.metrics)
        }
        .navigationDestination(isPresented: $personViewPresented) {
            if let person = selectedPerson {
                PersonView(person: .init(info: person))
            }
        }
        .task(priority: .userInitiated) {
            do {
                print("movie.fetchRelatedData")
                try await movie.fetchRelatedData()
            } catch {
                print("fetchMovieDetail error, \(error)")
            }
            
        }
        
    }
}

extension MovieDetailView {
    
    @ViewBuilder
    func BackdropOverlayView() -> some View {
        VStack(alignment: .leading) {
            Text(verbatim: movie.metadata.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                
            
            HStack(alignment: .center, spacing: 5) {
                if let voteAverage = movie.metadata.voteAverage {
                    Rectangle()
                        .overlay {
                            GeometryReader { proxy in
                                Color.yellow
                                    .frame(width: proxy.size.width * voteAverage / 10)
                            }
                        }
                        .mask(alignment: .leading) {
                            Image(systemName: "star.fill")
                                .resizable()
                               
                        }
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 15, height: 15)
                    
                    Text(voteAverage.formatted(.number.precision(.fractionLength(1))))
                }
                
                if let releaseDate = movie.metadata.releaseDate {
                    Text(releaseDate.formatted(
                        date: .abbreviated,
                        time:.omitted))
                }
                
                
                if let runtime = movie.metadata.runtime {
                    Text(TimeInterval(runtime * 60).formatted(unitsStyle: .full,
                                                              zeroFormattingBehavior: .dropAll))
                }
            }
            
            if let genres = movie.metadata.genres {
                HStack {
                    ForEach(genres) { genre in
                        Text(genre.name)
                            .padding(5)
                            .background {
                                RoundedRectangle(cornerRadius: .defaultCornerRadius)
                                    .opacity(0.6)
                            }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    func DetailView() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            
            HStack(alignment: .top) {
                
                Button {
                    playerPresented = true
                } label: {
                    Label(movie.metrics.progress == 0 ? "common.play" : "common.resume", systemImage: "play.fill")
                        .font(.title)
                        .padding(5)
                }
                .cursor()
                
                if let overview = movie.metadata.overview {
                    VStack(alignment: .leading) {
                        Text("movie.overview")
                            .font(.title)
                            .fontWeight(.bold)
                        Text(overview)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Spacer()
            }
            
            Section {
                CastView()
                    .focusable()
                    .focusEffectDisabled()
                    .onKeyPress(.return) {
                        if selectedPerson != nil {
                            personViewPresented = true
                        }
                        return .handled
                    }
            } header: {
                Text("movie.cast")
                    .font(.title)
                    .fontWeight(.bold)
            }
            
            
            
            Section {
                PostersView()
            } header: {
                Text("movie.posters")
                    .font(.title)
                    .fontWeight(.bold)
            }

            Section {
                BackdropsView()
            } header: {
                Text("movie.backdrops")
                    .font(.title)
                    .fontWeight(.bold)
            }
            
            Section {
                CrewView()
                    .onKeyPress(.return) {
                        if selectedPerson != nil {
                            personViewPresented = true
                            return .handled
                        }
                        return .ignored
                    }
            } header: {
                Text("movie.crew")
                    .font(.title)
                    .fontWeight(.bold)
            }
        }
        .safeAreaPadding(10)
    }
    
    @ViewBuilder
    func CastView() -> some View {
        HorizontalScrollView {
            HStack(alignment: .top) {
                ForEach(movie.cast.sorted(using: KeyPathComparator(\.order)) ?? []) { castMember in
                    let selected = selectedPerson?.id == castMember.id
                    VStack(alignment: .leading) {
                        AsyncImage(url: castMember.profilePath,
                                   transaction: .init(animation: .smooth)
                        ) { phase in
                            switch phase {
                            case .empty:
                                DefaultAvatarView()
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .failure(let error):
                                ErrorImageView(error: error)
                            @unknown default:
                                fatalError()
                            }
                        }
                        .frame(width: profileSize.width,
                               height: profileSize.height)
                        .clipped()
                        .cornerRadius()
                        .cursor()
                        
                        Group {
                            Text(castMember.name)
                                .font(.title3)
                                .fontWeight(.bold)
                                
                            Text(castMember.character)
                                .font(.headline)
                                
                        }
                        .fontWidth(.condensed)
                        .fontDesign(.rounded)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                    }
                    .frame(width: profileSize.width)
                    .scaleEffect(selected)
                    .onTapGesture {
                        selectedPerson = Person(
                            id: castMember.id,
                            name: castMember.name,
                            gender: Gender.unknown)
                    }
                    .simultaneousGesture(
                        TapGesture(count: 2)
                            .onEnded {
                                personViewPresented = true
                            }
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    func CrewView() -> some View {
        ForEach(groudedCrew.keys.sorted()) { department in
            Section {
                HorizontalScrollView {
                    HStack(alignment: .top) {
                        ForEach(groudedCrew[department] ?? []) { crewMember in
                            let selected = selectedPerson?.id == crewMember.id
                            VStack(alignment: .leading) {
                                AsyncImage(url: crewMember.profilePath,
                                           transaction: .init(animation: .smooth)
                                ) { phase in
                                    switch phase {
                                    case .empty:
                                        DefaultAvatarView()
                                    case .success(let image):
                                        image.resizable().scaledToFill()
                                    case .failure(let error):
                                        ErrorImageView(error: error)
                                    @unknown default:
                                        fatalError()
                                    }
                                }
                                .frame(width: profileSize.width,
                                       height: profileSize.height)
                                .clipped()
                                .cornerRadius()
                                
                                Group {
                                    Text(crewMember.name)
                                        .font(.title3)
                                        .fontWeight(.bold)

                                    Text(crewMember.job)
                                        .font(.headline)
                                        
                                }
                                .multilineTextAlignment(.leading)
                            }
                            .frame(width: profileSize.width)
                            .scaleEffect(selected)
                            .onTapGesture {
                                selectedPerson = Person(
                                    id: crewMember.id,
                                    name: crewMember.name,
                                    gender: Gender.unknown)
                            }
                            .simultaneousGesture(
                                TapGesture(count: 2)
                                    .onEnded {
                                        personViewPresented = true
                                    }
                            )
                        }
                    }
                }
            } header: {
                Text(department)
                    .font(.title2)
                    .fontWeight(.bold)
            }
        }
    }
    
    @ViewBuilder
    func PostersView() -> some View {
        ScrollView(.horizontal) {
            HStack(alignment: .center) {
                ForEach(movie.posters) { poster in
                    AsyncImage(url: poster.filePath,
                               transaction: .init(animation: .smooth)
                    ) { phase in
                        switch phase {
                        case .empty:
                            DefaultImageView()
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure(let error):
                            ErrorImageView(error: error)
                        @unknown default:
                            fatalError()
                        }
                    }
                    .frame(width: CGFloat(poster.aspectRatio) * 200, height: 200)
                    .cornerRadius()
                }
            }
        }

    }
    
    @ViewBuilder
    func BackdropsView() -> some View {
        ScrollView(.horizontal) {
            HStack(alignment: .center) {
                ForEach(movie.backdrops) { backdrop in
                    AsyncImage(url: backdrop.filePath,
                               transaction: .init(animation: .smooth)
                    ) { phase in
                        switch phase {
                        case .empty:
                            DefaultImageView()
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure(let error):
                            ErrorImageView(error: error)
                        @unknown default:
                            fatalError()
                        }
                     }
                    .frame(width: CGFloat(backdrop.aspectRatio) * 200, height: 200)
                    .cornerRadius()
                }
            }
        }
    }
}

#Preview {
    MovieDetailView(movie: MovieDetail.examples()[0])
}
