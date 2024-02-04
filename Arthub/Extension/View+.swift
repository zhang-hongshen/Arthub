//
//  Shape.swift
//  shelf
//
//  Created by 张鸿燊 on 31/1/2024.
//

import Foundation
import SwiftUI

struct RoundedRectangleModifier: ViewModifier {
    let cornerRadius: CGFloat

    init(cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    func rounded(cornerRadius: CGFloat = .defaultCornerRadius) -> some View {
        self.modifier(RoundedRectangleModifier(cornerRadius: cornerRadius))
    }
}
