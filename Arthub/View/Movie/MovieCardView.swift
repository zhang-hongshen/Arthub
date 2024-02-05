//
//  MovieCardView.swift
//  Arthub
//
//  Created by 张鸿燊 on 31/1/2024.
//

import SwiftUI

struct MovieCardView: View {
    
    @Binding var movie: Movie
    @State var frameWidth: CGFloat = 200

    var body: some View {
        VStack(alignment: .leading) {
            Image(movie.thumbnail)
                .resizable()
                .frame(width: frameWidth, height: frameWidth * 1.4)
                .scaledToFill()
                .aspectRatio(contentMode: .fill)
                .rounded()
            HStack(alignment: .center) {
                VStack(alignment: .leading) {
                    Text(movie.name)
                        .font(.title2)
                    Text(movie.releaseYear)
                }
                Spacer()
                if (movie.progress > 0) {
                    HStack(spacing: 5) {
                        ProgressView(value: movie.progress, total: 1)
                            .progressViewStyle(.circular)
                        Text("\(movie.progress.formatted(.percent))")
                    }
                    .font(.footnote)
                }
            }
        }
        .padding(10)
    }
    
}

#Preview {
    MovieCardView(movie: .constant(Movie.examples()[0]))
}
