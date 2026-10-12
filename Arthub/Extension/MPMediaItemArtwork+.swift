//
//  MPMediaItemArtwork+.swift
//  Arthub
//
//  Created by 张鸿燊 on 1/3/2024.
//

import MediaPlayer

extension MPMediaItemArtwork {

    convenience init?(data: Data) {
        guard let image = PlatformImage(data: data) else { return nil }
        self.init(boundsSize: image.size) { _ in image }
    }

    /// A local image file, or a TMDb image downloaded once into the artwork cache.
    convenience init?(contentsOf url: URL) async {
        guard let image = await ArtworkStore.shared.image(for: url) else { return nil }
        self.init(boundsSize: image.size) { _ in image }
    }
}
