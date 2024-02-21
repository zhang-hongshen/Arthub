//
//  ImageCollection+.swift
//  Arthub
//
//  Created by 张鸿燊 on 19/2/2024.
//

import Foundation
import TMDb

extension ImageCollection {
    
    func copy(
        id: Int? = nil,
        posters: [ImageMetadata]? = nil,
        logos: [ImageMetadata]? = nil,
        backdrops: [ImageMetadata]? = nil
    ) -> ImageCollection {
        return ImageCollection(
            id: id ?? self.id,
            posters: posters ?? self.posters,
            logos: logos ?? self.logos,
            backdrops: backdrops ?? self.backdrops
        )
    }
}
