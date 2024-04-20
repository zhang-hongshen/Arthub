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
            cast: [CastMember]? = nil,
            crew: [CrewMember]? = nil
        ) -> ShowCredits {
            return ShowCredits(
                id: self.id,
                cast: cast ?? self.cast,
                crew: crew ?? self.crew
            )
        }
}
