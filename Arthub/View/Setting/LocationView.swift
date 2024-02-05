//
//  LocationView.swift
//  Arthub
//
//  Created by 张鸿燊 on 5/2/2024.
//

import SwiftUI

struct LocationView: View {
    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline) {
            GridRow {
                Text("settings.locations.movieData").gridColumnAlignment(.trailing)

                Text(FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).description + UserDefaults.LibraryLocation.movie.rawValue)
            }
            GridRow {
                Text("settings.locations.musicData").gridColumnAlignment(.trailing)

                Text(FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).description + UserDefaults.LibraryLocation.music.rawValue)
            }
        }
        .font(.title3)
    }
}

#Preview {
    LocationView()
}
