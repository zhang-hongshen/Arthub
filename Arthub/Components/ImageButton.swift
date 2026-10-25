//
//  ImageButton.swift
//  Arthub
//
//  Created by 张鸿燊 on 13/3/2024.
//

import SwiftUI

// MARK: TagGesture Area is the image

struct ImageButton<Label>: View where Label: View {
    var systemImage: String
    /// What the button does, read by VoiceOver and agents. Without one it's only a placeholder
    /// picture and hidden from accessibility.
    var title: LocalizedStringKey?
    var label: () -> Label
    var action: () -> Void
    
    init(_ title: LocalizedStringKey? = nil,
         action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label) {
        self.systemImage = ""
        self.title = title
        self.label = label
        self.action = action
    }
    
    init(_ title: LocalizedStringKey? = nil,
         systemImage: String,
         action: @escaping () -> Void = {},
         @ViewBuilder label: @escaping () -> Label = { EmptyView() }) {
        self.systemImage = systemImage
        self.title = title
        self.label = label
        self.action = action
    }
    
    var body: some View {
        GeometryReader { proxy in
            Rectangle().fill(.ultraThinMaterial.opacity(0.5))
                .overlay {
                    Button(action: action) {
                        Group {
                            if systemImage != "" {
                                Image(systemName: systemImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            }
                            else {
                                label()
                            }
                        }
                        .frame(width: proxy.size.width / 4,
                               height: proxy.size.height / 4)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(title ?? "")
                }
                .contentShape(Rectangle())
        }
        .accessibilityHidden(title == nil)
    }
}

#Preview {
    ImageButton(systemImage: "photo")
}
