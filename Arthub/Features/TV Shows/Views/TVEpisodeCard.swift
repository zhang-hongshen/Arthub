//
//  TVEpisodeCard.swift
//  Arthub
//
//  Created by 张鸿燊 on 28/2/2024.
//

import SwiftUI

struct TVEpisodeCard: View {
    
    var episode: TVEpisodeDetail
    @State var width: CGFloat
    
    var body: some View {
        VStack(alignment: .leading) {
            
            TVEpisodeStill()
            
            Group {
                Text(verbatim: episode.metadata.name).font(.headline)
                Text("Episode \(episode.metadata.episodeNumber)").font(.subheadline)
            }
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            
            
        }
        .frame(width: width)
        .task{ await fetchData() }
    }
    
}

extension TVEpisodeCard {
    
    @ViewBuilder
    func TVEpisodeStill() -> some View {
        ImageLoader(url: episode.metadata.stillPath, aspectRatio: Landscape.aspectRatio)
            .frame(width: width, height: width / Landscape.aspectRatio)
            .overlay(alignment: .bottomLeading) {
                TVEpisodeStillOverlay()
            }
            .shadow()
            .cornerRadius()
            .contextMenu { TVEpisodeStillContextMenu() }
    }
    
    @ViewBuilder
    func TVEpisodeStillOverlay() -> some View {
        Color.accent
            .frame(width: width * episode.progress,
                   height: Default.cornerRadius)
    }
    
    @ViewBuilder
    func TVEpisodeStillContextMenu() -> some View {
        ShareLink(item: episode.fileURL,
                  subject: Text(verbatim: episode.metadata.name),
                  message: Text(verbatim: episode.metadata.overview ?? "" )) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
    }
}

extension TVEpisodeCard {
    
    func fetchData() async {
        do { try await episode.fetchDetail() }
        catch {}
    }
}
