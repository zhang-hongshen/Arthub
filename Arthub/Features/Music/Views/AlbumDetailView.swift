//
//  AlbumDetailView.swift
//  Arthub
//
//  Created by 张鸿燊 on 17/3/2024.
//

import SwiftUI
import OrderedCollections

struct AlbumDetailView: View {
    
    var album: AlbumDetail
    
    private var groupedAlbum: OrderedDictionary<Int, [MusicDetail]> {
        var res: OrderedDictionary<Int, [MusicDetail]> = [:]
        album.musics.forEach { music in
            guard let discNumber = music.discNumber else { return }
            res.updateValue(forKey: discNumber, default: []) { $0.append(music)}
        }
        return res
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                HStack(alignment: .center) {
                    ImageLoader(data: album.cover, aspectRatio: 1)
                        .frame(width: 300)
                        .shadow()
                        .cornerRadius()
                    
                    VStack(alignment: .leading) {
                        Text(album.title).font(.largeTitle.bold())
                        Text(album.artist.name).font(.headline)
                        Text(album.releaseDate?.formatted() ?? "").font(.subheadline)
                    }
                    
                    Spacer()
                }
                
                ForEach(groupedAlbum.elements, id: \.key) { discNumber, musics in
                    Section {
                        ForEach(musics.sorted(using: KeyPathComparator(\.trackNumber))) { music in
                            HStack(alignment: .center) {
                                Text(music.trackNumber?.formatted() ?? "")
                                
                                VStack(alignment: .leading) {
                                    Text(music.title)
                                    Text(music.artist.name)
                                }
                                
                                Spacer()
                                Text(music.duration.formatted())
                            }
                        }
                    } header: {
                        Text("Disc \(discNumber)").font(.title.bold())
                    }
                }
            }
            .safeAreaPadding()
        }
    }
}
