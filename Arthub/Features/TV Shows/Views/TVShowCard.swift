//
//  TVShowCard.swift
//  Arthub
//
//  Created by 张鸿燊 on 28/2/2024.
//

import SwiftUI

struct TVShowCard: View {
    
    var tvShow: TVShowDetail
    @State var width: CGFloat
    
    @State private var fetchDataTask: Task<Void, Error>? = nil
    @State private var sheetPreseted = false
    
    var body: some View {
        VStack(alignment: .leading) {
            TVShowPoster()
            
            Text(tvShow.metadata.name).font(.headline)
                .lineLimit(2).multilineTextAlignment(.leading)

            Text("\(tvShow.seasons.count) Season").font(.subheadline)
            
        }
        .frame(width: width)
        .sheet(isPresented: $sheetPreseted) {
            // An empty sheet has no size and no buttons, so it locked the window.
            if let fileID = tvShow.seasons.lazy.flatMap(\.episodes).first?.fileID,
               let file = LibraryViewModel.shared.files.first(where: { $0.id == fileID }) {
                LibraryMatchView(file: file, applyToShow: true)
            } else {
                MissingFileSheet()
            }
        }
    }
    
}

extension TVShowCard {
    
    @ViewBuilder
    func TVShowPoster() -> some View {
        ArtworkImage(url: tvShow.metadata.posterPath, 
                    aspectRatio: Portrait.aspectRatio) {
            ImageButton(systemImage: "film.stack")
        }
        .frame(width: width, height: width / Portrait.aspectRatio)
        .clipped()
        .overlay(alignment: .bottomLeading) {
            Color.accent
                .frame(width: width * tvShow.progress,
                       height: Default.cornerRadius)
        }
        .shadow()
        .cornerRadius()
        .contextMenu { TVShowPosterContextMenu() }
    }
    
    @ViewBuilder
    func TVShowPosterContextMenu() -> some View {
        Button("Edit Metadata", systemImage: "square.and.pencil", action: { sheetPreseted = true })
    }
}
