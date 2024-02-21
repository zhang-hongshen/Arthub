//
//  PersonView.swift
//  Arthub
//
//  Created by 张鸿燊 on 20/2/2024.
//

import Foundation
import SwiftUI
import TMDb


private struct InfoViewHeightPreference : PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct PersonView : View {
    
    @State var person: PersonDetail
    @State private var profileSize: CGSize = .init(width: 200, height: 300)
    @State private var infoViewMinWidth: CGFloat = 100
    
    var body: some View {
        ScrollView {
            HStack(alignment: .top) {
                AsyncImage(url: person.info.profilePath,
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
                .frame(width: profileSize.width,
                       height: profileSize.height)
                .cornerRadius()
                
                InfoView()
                    .overlay {
                        GeometryReader { proxy in
                            Color.clear
                                .preference(
                                    key: InfoViewHeightPreference.self,
                                    value: proxy.size)
                        }
                    }
                    .safeAreaPadding(10)
                    .frame(minWidth: infoViewMinWidth)
                
                Spacer()
            }
            
            
            VStack(alignment: .leading) {
                
                Text("person.biography")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                if let biography = person.info.biography {
                    Text(biography)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Text("person.knownForMovies")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                KnownForMoviesView()
            }
            
        }
        .safeAreaPadding(10)
        .frame(minWidth: profileSize.width + infoViewMinWidth)
        .navigationTitle(person.info.name)
        
        .task {
            do {
                async let getImageConfiguration = ConfigurationService.shared.getImageConfiguration()
                async let fetchDetail = PersonService.shared.details(forPerson: person.info.id)
                let (imageConfiguration, info) =  try await (getImageConfiguration, fetchDetail)
                self.person = PersonDetail(
                    info: info.copy(
                        profilePath: imageConfiguration.profileURL(for: info.profilePath)
                    ))
                try await person.fetchRelatedData()
            } catch {
                
            }
        }
    }
    
}

extension PersonView {
    
    @ViewBuilder
    func InfoView() -> some View {
        
        Grid(alignment: .leadingFirstTextBaseline, verticalSpacing: 10) {
            GridRow {
                Text(verbatim: person.info.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            
            GridRow {
                Text("person.birthday")
                    .gridColumnAlignment(.listRowSeparatorLeading)
                Text("person.placeOfBirth")
            }
            .font(.title)
            
            GridRow {
                if let birthday = person.info.birthday {
                    Text(birthday.formatted(date: .abbreviated, time: .omitted))
                        .gridColumnAlignment(.listRowSeparatorLeading)
                }
                
                if let placeOfBirth = person.info.placeOfBirth {
                    Text(placeOfBirth)
                }
            }
            
            GridRow {
                Text("person.knownFor")
                    .gridColumnAlignment(.listRowSeparatorLeading)
            }
            .font(.title)
            
            GridRow {
                
                if let knownFor = person.info.knownForDepartment {
                    Text(knownFor)
                        .gridColumnAlignment(.listRowSeparatorLeading)
                }
                    
            }
        }
        
    }
    
    @ViewBuilder
    func KnownForMoviesView() -> some View {
        HorizontalScrollView {
            HStack {
                ForEach(person.knownForMovies) { movie in
                    VStack {
                        AsyncImage(url: movie.posterPath,
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
                        
                        Text(movie.title)
                    }
                }
            }
            
        }
    }
    
    @ViewBuilder
    func ProfilesView() -> some View {
        HorizontalScrollView {
            HStack {
                ForEach(person.profiles) { profile in
                        AsyncImage(url: profile.filePath,
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
                        .frame(width: 150,
                               height: 200)
                        .clipped()
                }
            }
            
        }
    }
}
