//
//  ArthubError.swift
//  Arthub
//
//  Created by 张鸿燊 on 7/3/2024.
//

import Foundation
import SwiftUI

enum ArthubError: Error, LocalizedError {
    case connectionFailed
    case error(Error)
    
    var localizedDescription: String {
        switch self {
        case .connectionFailed:
            "Connection Failed"
        case .error(let error):
            error.localizedDescription
        }
    }
    
}
