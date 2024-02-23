//
//  MusicCardView.swift
//  Shelf
//
//  Created by 张鸿燊 on 1/2/2024.
//

import SwiftUI

struct MusicCardView: View {
    
    @Binding var music: Music
    @State var frameWidth: CGFloat
    
    var body: some View {
        VStack(alignment: .center) {
            
            AsyncImage(url: music.album?.cover,
                       transaction: .init(animation: .smooth)
            ) { phase in
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
            .scaledToFill()
            .frame(width: frameWidth, height: frameWidth)
            .cornerRadius()
            
            Text(music.title)
                .font(.title2)
            
            Text(music.artists.formatted())
        }
    }
}
