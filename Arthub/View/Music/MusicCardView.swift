//
//  MusicCardView.swift
//  Shelf
//
//  Created by 张鸿燊 on 1/2/2024.
//

import SwiftUI

struct MusicCardView: View {
    
    @Bindable var music: Music
    @State var frameWidth: CGFloat = 200
    
    var body: some View {
        VStack(alignment: .center) {
            let imageWidth = frameWidth * 0.8
            Image(music.thumbnail)
                .resizable()
                .frame(width: imageWidth, height: imageWidth)
                .scaledToFit()
                .aspectRatio(contentMode: .fill)
                .rounded()
            Text(music.name)
                .font(.title2)
        }
        .padding(10)
    }
}

#Preview {
    MusicCardView(music: Music.examples()[0])
}
