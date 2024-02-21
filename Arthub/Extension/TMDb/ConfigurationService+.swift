//
//  ConfigurationService+.swift
//  Arthub
//
//  Created by 张鸿燊 on 17/2/2024.
//

import TMDb

extension ConfigurationService {
    static let shared = ConfigurationService()
    
    func getImageConfiguration() async throws -> ImagesConfiguration {
        let apiConfiguration = try await apiConfiguration()
        return apiConfiguration.images
    }
}
