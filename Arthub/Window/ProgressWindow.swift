//
//  ProgressWindow.swift
//  Arthub
//
//  Created by 张鸿燊 on 15/2/2024.
//

import Foundation
import SwiftUI

func ProgressWindow() -> some Scene {
    WindowGroup("", id: "window.progress", for: Double.self) { current in
        if let value = current.wrappedValue {
            VStack {
                ProgressView(value: value) {
                    Text(value.rounded().formatted())
                }
                .padding(10)
                .frame(width: 300, height: 60)
                .fixedSize()
            }
            .padding(10)
            .applyUserSettings()
        }
    }
}

