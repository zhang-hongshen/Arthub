//
//  CrewMember+.swift
//  Arthub
//
//  Created by 张鸿燊 on 18/2/2024.
//

import Foundation
import TMDb

extension CrewMember {
    
    public func copy(
        creditID: String? = nil,
        name: String? = nil,
        job: String? = nil,
        department: String? = nil,
        gender: Gender? = nil,
        profilePath: URL? = nil
    ) -> Self {
        return Self(
            id: self.id,
            creditID: creditID ?? self.creditID,
            name: name ?? self.name,
            job: job ?? self.job,
            department: department ?? self.department,
            gender: gender ?? self.gender,
            profilePath: profilePath ?? self.profilePath
        )
    }
}
