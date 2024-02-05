//
//  MovieInspectorView.swift
//  Arthub
//
//  Created by 张鸿燊 on 31/1/2024.
//

import SwiftUI

struct MovieInspectorView: View {
    
    @Binding var movie: Movie
    
    var body: some View {
        VStack(alignment: .leading) {
            Image(movie.thumbnail)
                .resizable()
                .scaledToFit()
                .rounded()
            Grid(alignment: .leadingFirstTextBaseline) {
                
                GridRow {
                    Text("movie.name").gridColumnAlignment(.trailing)
                    TextField("movie.name", text: $movie.name)
                        .fixedSize()
                        .rounded()
                }
                
                GridRow {
                    Text("movie.releaseYear").gridColumnAlignment(.trailing)
                    TextField("movie.releaseYear", text: $movie.releaseYear)
                        .fixedSize()
                        .rounded()
                }
            }
        }
        .font(.title2)
        .padding(10)
    }
}

#Preview {
    MovieInspectorView(movie: .constant(Movie.examples()[0]))
}
