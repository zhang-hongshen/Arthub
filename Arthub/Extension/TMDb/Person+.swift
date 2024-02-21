//
//  Person+.swift
//  Arthub
//
//  Created by 张鸿燊 on 20/2/2024.
//

import Foundation
import TMDb

extension Person {
    
    func copy(
        name: String? = nil,
        alsoKnownAs: [String]? = nil,
        knownForDepartment: String? = nil,
        biography: String? = nil,
        birthday: Date? = nil,
        deathday: Date? = nil,
        gender: Gender? = nil,
        placeOfBirth: String? = nil,
        profilePath: URL? = nil,
        popularity: Double? = nil,
        imdbID: String? = nil,
        homepageURL: URL? = nil
    ) -> Self {
        return .init(
            id: self.id,
            name: name ?? self.name,
            alsoKnownAs: alsoKnownAs ?? self.alsoKnownAs,
            knownForDepartment: knownForDepartment ?? self.knownForDepartment,
            biography: biography ?? self.biography,
            birthday: birthday ?? self.birthday,
            deathday: deathday ?? self.deathday,
            gender: gender ?? self.gender,
            placeOfBirth: placeOfBirth ?? self.placeOfBirth,
            profilePath: profilePath ?? self.profilePath,
            popularity: popularity ?? self.popularity,
            imdbID: imdbID ?? self.imdbID,
            homepageURL: homepageURL ?? self.homepageURL
        )
    }
}
