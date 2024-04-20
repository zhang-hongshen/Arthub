//
//  PersonDetailView.swift
//  Arthub
//
//  Created by 张鸿燊 on 20/2/2024.
//

import Foundation
import SwiftUI
import TMDb

struct PersonDetailView : View {
    
    var person: PersonDetail
    
    @State private var fetchDataTask: Task<Void, Error>? = nil
    @State private var profileSize = CGSize(width: Portrait.width(),
                                            height: Portrait.height(.small))
    
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading) {
                    if proxy.size.width > profileSize.width + 150 {
                        HStack(alignment: .top) {
                            ProfileView()
                            InfoView()
                                .safeAreaPadding()
                            Spacer()
                        }
                    } else {
                        VStack(alignment: .leading) {
                            ProfileView()
                            InfoView()
                        }
                    }
                    BiographySectionView()
                    KnownForMoviesSectionView()
                    ProfilesSectionView()
                }
            }
            
        }
        .safeAreaPadding()
        .frame(minWidth: profileSize.width)
        .scrollIndicators(.never, axes: .vertical)
        .task{ fetchData() }
        .onDisappear(perform: fetchDataTask?.cancel)
    }
    
}

extension PersonDetailView {
    
    @ViewBuilder
    func ProfileView() -> some View {
        ImageLoader(url: person.metadata.profilePath)
            .frame(width: profileSize.width,
                   height: profileSize.height)
            .cornerRadius()
    }
    
    
    @ViewBuilder
    func InfoView() -> some View {
        Grid(verticalSpacing: 10) {
            GridRow {
                Text(verbatim: person.metadata.name)
                    .font(.largeTitle.bold())
            }
            
            GridRow {
                Text("Birthday")
                    .gridColumnAlignment(.leading)
                Text("Place Of Birth")
                    .gridColumnAlignment(.leading)
                Text("Known For")
                    .gridColumnAlignment(.leading)
            }
            .font(.title3.bold())
            
            GridRow {
                if let birthday = person.metadata.birthday {
                    Text(birthday.formatted(date: .abbreviated, time: .omitted))
                }
                
                if let placeOfBirth = person.metadata.placeOfBirth {
                    Text(placeOfBirth)
                }
                
                if let knownFor = person.metadata.knownForDepartment {
                    Text(knownFor)
                }
            }
            
            GridRow {
                Text("Also Known As")
                    .gridCellColumns(3)
                    .gridCellAnchor(.leading)
            }
            
            .font(.title3.bold())
            
            GridRow {
                if let alsoKnownAs = person.metadata.alsoKnownAs {
                    Text(alsoKnownAs.joined(separator: ","))
                        .gridCellColumns(3)
                        .gridCellAnchor(.leading)
                }
            }
        }
        
    }
}

// MARK: Biography Section

extension PersonDetailView {
    
    @ViewBuilder
    func BiographySectionView() -> some View {
        Section {
            Text(person.metadata.biography ?? "")
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        } header: {
            Text("Biography").font(.title.bold())
        }
        
    }
}

// MARK: Known For Movies Section

extension PersonDetailView {
    
    @ViewBuilder
    func KnownForMoviesSectionView() -> some View {
        Section {
            KnownForMoviesView()
        } header: {
            Text("Known For Movies").font(.title.bold())
        }

    }
    
    @ViewBuilder
    func KnownForMoviesView() -> some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top) {
                ForEach(person.knownForMovies
                    .sorted(using: KeyPathComparator(\.releaseDate, order: .reverse))) { movie in
                    VStack(alignment: .leading) {
                        ImageLoader(url: movie.posterPath, aspectRatio: Portrait.aspectRatio)
                            .frame(width: Portrait.width(.small), height: Portrait.height(.small))
                            .clipped()
                            .shadow()
                            .cornerRadius()
                        
                        VStack(alignment: .leading) {
                            Text(movie.title)
                                .font(.headline)
                                .multilineTextAlignment(.leading)

                            if let releaseDate = movie.releaseDate {
                                Text(releaseDate.formatted(.dateTime.year()))
                                    .font(.subheadline)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(width: Portrait.width(.small))
                }
            }
        }
    }
}

// MARK: Profiles Section

extension PersonDetailView {
    
    @ViewBuilder
    func ProfilesSectionView() -> some View {
        Section {
            ProfilesView()
        } header: {
            Text("Profiles")
                .font(.largeTitle.bold())
        }

    }
    
    @ViewBuilder
    func ProfilesView() -> some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top) {
                ForEach(person.profiles) { profile in
                    ImageLoader(url: profile.filePath, aspectRatio: Portrait.aspectRatio)
                        .frame(width: Portrait.width(.small),
                               height: Portrait.height(.small))
                        .clipped()
                        .cornerRadius()
                }
            }
            
        }
    }
}

extension PersonDetailView {
    
    func fetchData() {
        fetchDataTask = Task {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { try await person.fetchDetail() }
                group.addTask { try await person.fetchRelatedData() }
                try await group.waitForAll()
            }
        }
    }
}
