//
//  MuscListView.swift
//  Arthub
//
//  Created by 张鸿燊 on 2/2/2024.
//

import SwiftUI

struct MusicListView: View {
    @Bindable var music: Music
    @State var height: CGFloat = 50
    
    var body: some View {
        HStack(alignment: .center) {
            Image(music.thumbnail)
                .resizable()
                .frame(width: height, height: height)
                .scaledToFit()
                .aspectRatio(contentMode: .fill)
                .rounded()
            Text(music.name)
                .font(.title2)
        }
        .padding(5)
    }
}

#Preview {
    MusicListView(music: Music.examples()[0])
}
