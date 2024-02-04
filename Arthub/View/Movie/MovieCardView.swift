//
//  MovieCardView.swift
//  shelf
//
//  Created by 张鸿燊 on 31/1/2024.
//

import SwiftUI

struct MovieCardView: View {
    
    @Binding var movie: Movie
    @State var frameWidth: CGFloat = 200

    var body: some View {
        VStack(alignment: .leading) {
            let imageWidth = frameWidth * 0.8
            Image(movie.thumbnail)
                .resizable()
                .frame(width: imageWidth, height: imageWidth * 1.4)
                .scaledToFit()
                .aspectRatio(contentMode: .fill)
                .rounded()
            Text(movie.name)
                .font(.title2)
            Text(movie.releaseYear)
            if (movie.progress > 0) {
                HStack(spacing: 5) {
                    ProgressView(value: movie.progress, total: 1)
                        .progressViewStyle(.circular)
                    Text("\((movie.progress * 100).rounded().formatted())%")
                }
                .font(.footnote)
            }
        }
        .padding(10)
    }
    
}

#Preview {
    MovieCardView(movie: .constant(Movie.examples()[0]))
}
