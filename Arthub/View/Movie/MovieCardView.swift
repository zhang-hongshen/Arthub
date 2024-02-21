//
//  MovieCardView.swift
//  Arthub
//
//  Created by 张鸿燊 on 31/1/2024.
//

import SwiftUI
import TMDb

struct MovieCardView: View {
    
    @State var movie: MovieDetail
    @State var frameWidth: CGFloat = 200

    var body: some View {
        VStack(alignment: .leading) {
            
            AsyncImage(url: movie.metadata.posterPath,
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
            .frame(width: frameWidth, height: frameWidth * 1.4)
            .clipped()
            .overlay(alignment: .bottomLeading) {
                Color.selectedContentBackgroundColor
                    .frame(width: frameWidth * movie.metrics.progress,
                           height: .defaultCornerRadius)
            }
            .cornerRadius()
            .cursor()
            

            Text(movie.metadata.title)
                .font(.title)
                .fontWeight(.bold)

            if let releaseDate = movie.metadata.releaseDate {
                Text(releaseDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.title3)
            }
        }
        .frame(width: frameWidth)
    }
    
}

#Preview {
    MovieCardView(movie: MovieDetail.examples()[0])
}
