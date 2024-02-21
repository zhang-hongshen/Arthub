//
//  SettingsWindow.swift
//  Arthub
//
//  Created by 张鸿燊 on 21/2/2024.
//

import Foundation
import SwiftUI

func ErrorWindow() -> some Scene {
    WindowGroup("", id: "window.error", for: String.self) { error in
        if let err = error.wrappedValue {
            Text(verbatim: err)
        }
    }
}
