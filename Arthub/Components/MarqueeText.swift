//
//  SwiftUIView.swift
//  Arthub
//
//  Created by 张鸿燊 on 29/2/2024.
//

import SwiftUI

struct MarqueeText : View {
    
    @State var verbatim = ""
    
    @State private var spacing: CGFloat = 10
    @State private var contentSize: CGSize = .zero
    
    private enum MarqueeTextState {
        case idle
        case animating
    }
    
    @State private var state: MarqueeTextState = .idle
    
    private let animation = Animation.linear(duration: 10).delay(3).repeatForever(autoreverses: false)
    private var offsetX : CGFloat {
        switch self.state {
            case .idle: 0
        case .animating: -contentSize.width
        }
    }
    
    var body : some View {
        GeometryReader { proxy in
            Text(verbatim: verbatim).fixedSize()
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: ContentSizePreference.self,
                                        value: proxy.size)
                    }
                }
                .overlay {
                    if proxy.size.width < contentSize.width {
                        Text(verbatim: verbatim).fixedSize()
                            .offset(x: contentSize.width + spacing)
                    }
                }
                .offset(x: offsetX)
                .frame(height: contentSize.height)
                .onAppear {
                    resetAnimation(frameSize: proxy.size)
                }
                .onPreferenceChange(ContentSizePreference.self){ value in
                    contentSize = value
                    resetAnimation(frameSize: proxy.size)
                }
        }
        .clipped()
        
    }

    func resetAnimation(frameSize: CGSize) {
        if frameSize.width >= contentSize.width {
            stopAnimation()
            return
        }
        withAnimation(animation) {
            state = .animating
        }
    }
    
    func stopAnimation() {
        withAnimation {
            state = .idle
        }
    }
}


private struct ContentSizePreference: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value.height = max(value.height, nextValue().height)
        value.width = max(value.width, nextValue().width)
    }
}


#Preview {
    MarqueeText(verbatim: "This is some very long text for a song!")
        .frame(width: 100)
}
