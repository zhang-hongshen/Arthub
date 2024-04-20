//
//  Waveform.swift
//  Arthub
//
//  Created by 张鸿燊 on 14/3/2024.
//

import SwiftUI

struct Waveform: View {
    @State var animated: Bool = false
    
    @State private var animationTrigger: Bool = false
    
    private let num = 6
    private let spacing: CGFloat = 1
    private let animation = Animation.easeInOut(duration: 0.25)
        .repeatForever(autoreverses: true)
    
    var body: some View {
        GeometryReader { proxy in
            let remainingWidth: CGFloat = proxy.size.width - CGFloat(num - 1) * spacing
            let width: CGFloat =  remainingWidth / CGFloat(num)
            let heightRange: ClosedRange<CGFloat> = 1...proxy.size.height
            
            HStack(spacing: spacing){
                ForEach(0..<num) {_ in
                    RoundedRectangle(cornerRadius: width/2)
                        .frame(width: width,
                               height: animated ? .random(in: heightRange) : 0)
                        .foregroundStyle(.white)
                }
                .animation(animated ? animation : .none,
                           value: animationTrigger)
            }
            .onAppear {
                animationTrigger.toggle()
            }
        }
    }
}

#Preview {
    Waveform(animated: true)
        .frame(width: 30, height: 20)
}
