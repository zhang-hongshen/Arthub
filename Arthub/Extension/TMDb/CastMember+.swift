//
//  CastMember+.swift
//  Arthub
//
//  Created by 张鸿燊 on 18/2/2024.
//

import Foundation
import TMDb

extension CastMember {
    public func copy(
        castID: Int? = nil,
        creditID: String? = nil,
        name: String? = nil,
        character: String? = nil,
        gender: Gender? = nil,
        profilePath: URL? = nil,
        order: Int? = nil
    ) -> Self {
        .init(
            id: self.id,
            castID: castID ?? self.castID,
            creditID: creditID ?? self.creditID,
            name: name ?? self.name,
            character: character ?? self.character,
            gender: gender ?? self.gender,
            profilePath: profilePath ?? self.profilePath,
            order: order ?? self.order
        )
    }
}
