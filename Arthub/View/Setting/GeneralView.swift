//
//  GeneralView.swift
//  Arthub
//
//  Created by 张鸿燊 on 3/2/2024.
//

import SwiftUI

struct GeneralView: View {
    @AppStorage(UserDefaults.appearance)
    private var appearance: Appearance = .system

    @AppStorage(UserDefaults.movieMetadata)
    private var movieMetadata: MovieMetadata = .local
    
    @AppStorage(UserDefaults.musicMetadata)
    private var musicMetadata: MusicMetadata = .local
    
    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline,
             verticalSpacing: 10) {
            
            GridRow {
                Text("settings.appearance").gridColumnAlignment(.trailing)
                Picker("", selection: $appearance) {
                    Text("appearance.system").tag(Appearance.system)
                    Text("appearance.light").tag(Appearance.light)
                    Text("appearance.dark").tag(Appearance.dark)
                }
                .fixedSize()
            }
            
            GridRow {
                Text("settings.movieMetadata").gridColumnAlignment(.trailing)
                Picker("", selection: $movieMetadata) {
                    Text("movieMetadata.local").tag(MovieMetadata.local)
                    Text("movieMetadata.tmdb").tag(MovieMetadata.tmdb)
                }
                .fixedSize()
            }
            
            GridRow {
                Text("settings.musicMetadata").gridColumnAlignment(.trailing)
                Picker("", selection: $musicMetadata) {
                    Text("musicMetadata.local").tag(MusicMetadata.local)
                    Text("musicMetadata.musicbrainz").tag(MusicMetadata.musicbrainz)
                }
                .fixedSize()
            }
            
            Spacer()
        }
        .font(.title3)
    }
}

#Preview {
    GeneralView()
}
