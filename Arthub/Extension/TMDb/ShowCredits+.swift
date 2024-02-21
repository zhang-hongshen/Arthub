//
//  ShowCredits+.swift
//  Arthub
//
//  Created by 张鸿燊 on 19/2/2024.
//

import Foundation
import TMDb

extension ShowCredits {
    func copy(
            id: Int? = nil,
            cast: [CastMember]? = nil,
            crew: [CrewMember]? = nil
        ) -> ShowCredits {
            return ShowCredits(
                id: id ?? self.id,
                cast: cast ?? self.cast,
                crew: crew ?? self.crew
            )
        }
}
