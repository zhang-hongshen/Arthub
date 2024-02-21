//
//  MusicListItemView.swift
//  Arthub
//
//  Created by 张鸿燊 on 2/2/2024.
//

import SwiftUI

struct MusicListItemView: View {
    @Binding var music: Music
    @State var height: CGFloat = 50
    
    var body: some View {
        HStack(alignment: .center) {
            AsyncImage(url: music.album?.cover,
                       transaction: .init(animation: .smooth)
            ) { phase in
                switch phase {
                case .empty:
                    DefaultImageView()
                case .success(let image):
                    image.resizable().scaledToFit()
                case .failure(let error):
                    ErrorImageView(error: error)
                @unknown default:
                    fatalError()
                }
            }
            .frame(width: height, height: height)
            .cornerRadius()
            
            Text(music.title)
                .font(.title2)
        }
    }
}
