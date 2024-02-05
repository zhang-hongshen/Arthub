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
                volume = minmax(volume - volumeAdjustStep, min: 0, max: 1)
            } label: {
                Image(systemName: volume == 0 ? "speaker.slash.fill" : "speaker.fill")
            }
            .keyboardShortcut(.downArrow, modifiers: [])
            .buttonStyle(.borderless)
            
            Slider(value: $volume, in: 0...1) {
            }
            
            Button {
                volume = minmax(volume + volumeAdjustStep, min: 0, max: 1)
            } label: {
                Image(systemName: "speaker.wave.3.fill")
            }
            .keyboardShortcut(.upArrow, modifiers: [])
            .buttonStyle(.borderless)
        }
    }
    
    func minmax(_ value: Float, min: Float, max: Float) -> Float {
        if value > max {
            return max
        } else if value < min {
            return min
        }
        return value
    }
}

#Preview {
    VolumeBar(volume: .constant(0.3))
}
