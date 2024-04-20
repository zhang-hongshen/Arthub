//
//  ArthubSlider.swift
//  Arthub
//
//  Created by 张鸿燊 on 19/2/2024.
//

import Foundation
import SwiftUI

struct ArthubSlider<V>: View where V : BinaryFloatingPoint,
        V.Stride : BinaryFloatingPoint{
    
    @Binding var value: V
    var range: ClosedRange<V>
    var onEditingChanged : (Bool) -> Void = { _ in }
    var onHoveringValueChanged : (V) -> Void = { _ in }
    var onHoverEnded : () -> Void = {}
    @State private var lastX: CGFloat = 0
    @State private var isEditing: Bool = false
    @State private var hovering: Bool = false
    @State private var hoveringValue: V = 0
    private let scaleEffectY: CGFloat = 1.3
    
    init(value: Binding<V>,
         in range: ClosedRange<V> = 0...1,
         onEditingChanged: @escaping (Bool) -> Void = { _ in },
         onHoveringValueChanged: @escaping (V) -> Void = { _ in },
         onHoverEnded : @escaping () -> Void = {}) {
        self._value = value
        self.range = range
        self.onEditingChanged = onEditingChanged
        self.onHoveringValueChanged = onHoveringValueChanged
        self.onHoverEnded = onHoverEnded
    }
    
    var body: some View {
        GeometryReader { proxy in
            
            let frameSize = proxy.size
            let thumbWidth = frameSize.height * 0.2
            let sliderHeight = thumbWidth
            let radius = thumbWidth / 2
            let minX = radius
            let maxX = frameSize.width - radius
            let scaleFactor: CGFloat = (maxX - minX) / CGFloat(range.upperBound - range.lowerBound)
            let sliderX: CGFloat = (CGFloat((self.value - range.lowerBound)) * scaleFactor + minX).clamp(to: minX...maxX)
 
            ZStack(alignment: .leading) {
                Rectangle()
                    .opacity(0.2)
                    .frame(width: frameSize.width - thumbWidth,
                           height: sliderHeight)
                    .overlay(alignment: .leading) {
                        if sliderX > 0 {
                            Rectangle()
                                .opacity(0.6)
                                .frame(width: sliderX,
                                       height: sliderHeight)
                                .animation(.linear, value: sliderX)
                        }
                    }
                    .cornerRadius(radius)
                    .animation(.smooth, value: isEditing)
                    .scaleEffect(x: 1, y: isEditing ? scaleEffectY : 1)
                    .offset(x: radius / 2)
                    .onContinuousHover(coordinateSpace: .local) { phase in
                        self.hovering = true
                        switch phase {
                        case .active(let location):
                            hoveringValue = range.lowerBound + V((location.x - minX) / scaleFactor).clamp(to: range)
                        case .ended:
                            self.hovering = false
                            onHoverEnded()
                        }
                    }
                    #if !os(tvOS)
                    .onTapGesture(coordinateSpace: .local) { value in
                        onEditingChanged(true)
                        self.value = (range.lowerBound + V((value.x - minX) / scaleFactor)).clamp(to: range)
                        onEditingChanged(false)
                    }
                    #endif
                    .onChange(of: hoveringValue) { _, newValue in
                        onHoveringValueChanged(newValue)
                    }
                
                RoundedRectangle(cornerRadius: radius)
                    .frame(width: thumbWidth,
                           height: frameSize.height)
                    .offset(x: sliderX - radius)
                    .animation(.linear, value: sliderX)
                    .gesture (
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isEditing = true
                                onEditingChanged(true)
                                let translationX = value.translation.width
                                if(abs(translationX) < 0.1) {
                                    self.lastX = sliderX
                                }
                                let nextX = (self.lastX + translationX).clamp(to: minX...maxX)
                                self.value = (range.lowerBound + V((nextX - minX) / scaleFactor)).clamp(to: range)
                            }
                            .onEnded { value in
                                isEditing = false
                                onEditingChanged(false)
                            }
                    )
                    
            }
        }
        .frame(height: 25)
    }
    
}

#Preview {
    return ArthubSlider(value: .constant(0.75), in: 0...1)
}
