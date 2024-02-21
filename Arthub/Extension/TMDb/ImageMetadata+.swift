//
//  ImageMetadata+.swift
//  Arthub
//
//  Created by 张鸿燊 on 18/2/2024.
//

import Foundation
import TMDb

extension ImageMetadata {
    
    public func copy(
        filePath: URL? = nil,
        width: Int? = nil,
        height: Int? = nil,
        aspectRatio: Float? = nil,
        voteAverage: Float? = nil,
        voteCount: Int? = nil,
        languageCode: String? = nil
    ) -> Self {
        .init(
            filePath: filePath ?? self.filePath,
            width: width ?? self.width,
            height: height ?? self.height,
            aspectRatio: aspectRatio ?? self.aspectRatio,
            voteAverage: voteAverage ?? self.voteAverage,
            voteCount: voteCount ?? self.voteCount,
            languageCode: languageCode ?? self.languageCode
        )
    }
}
