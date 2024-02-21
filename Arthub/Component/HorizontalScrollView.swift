//
//  HorizontalScrollView.swift
//  Arthub
//
//  Created by 张鸿燊 on 18/2/2024.
//

import Foundation
import SwiftUI

struct HorizontalScrollView<Content: View>: View {
    
    @ViewBuilder var content: () -> Content
    
    @State private var minHeight: CGFloat = .zero
    @State private var shouldUpdateMinHeight = false
    
    var body: some View {
        ScrollView(.horizontal) {
          content()
            .background {
              GeometryReader { proxy in
                Color.clear.preference(
                  key: ScrollViewMinHeightPreference.self,
                  value: proxy.size.height
                )
              }
            }
        }
        .frame(minHeight: minHeight)
        .onPreferenceChange(ScrollViewMinHeightPreference.self) { newValue in
            if shouldUpdateMinHeight {
                self.minHeight = newValue
            }
        }
        .onChange(of: minHeight, initial: true) { _, _ in
            shouldUpdateMinHeight = false
        }
        .background {
            Color.clear.onAppear {
                shouldUpdateMinHeight = true
            }
        }
    }
}

private struct ScrollViewMinHeightPreference: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
