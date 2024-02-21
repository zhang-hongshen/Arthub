//
//  AutoWidthTabView.swift
//  Arthub
//
//  Created by 张鸿燊 on 17/2/2024.
//

import SwiftUI

struct AutoWidthTabView<SelectionValue: Hashable, Content: View>: View {
    
    var selection: Binding<SelectionValue>?
    @ViewBuilder var content: () -> Content
    
    @State private var minWidth: CGFloat = .zero

    var body: some View {
        TabView(selection: selection) {
          content()
            .background {
              GeometryReader { proxy in
                Color.clear.preference(
                  key: TabViewMinWidthPreference.self,
                  value: proxy.size.width
                )
              }
            }
        }
        .tabViewStyle(.automatic)
        .frame(minWidth: minWidth)
        .onPreferenceChange(TabViewMinWidthPreference.self) { newValue in
          self.minWidth = newValue
        }
    }
}

private struct TabViewMinWidthPreference: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
