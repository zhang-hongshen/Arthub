//
//  VolumeBar.swift
//  Arthub
//
//  Created by 张鸿燊 on 5/2/2024.
//

import SwiftUI

struct VolumeBar: View {
    @Binding var volume: Float
    @State var volumeAdjustStep: Float = 0.1
    
    var body: some View {
        HStack {
            Button {
                volume = (volume - volumeAdjustStep).clamp(to: 0...1)
            } label: {
                Image(systemName: "speaker")
                    .symbolVariant(volume == 0 ? .slash : .none)
            }
            .keyboardShortcut(.downArrow, modifiers: [])
            .buttonStyle(.borderless)
            
            Slider(value: $volume, in: 0...1) {
            }
            
            Button {
                volume = (volume + volumeAdjustStep).clamp(to: 0...1)
            } label: {
                Image(systemName: "speaker.wave.3", variableValue: Double(volume))
            }
            .keyboardShortcut(.upArrow, modifiers: [])
            .buttonStyle(.borderless)
        }
        .symbolVariant(.fill)
    }
}

#Preview {
    VolumeBar(volume: .constant(0.3))
}
