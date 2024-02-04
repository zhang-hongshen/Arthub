//
//  VolumeControlView.swift
//  Arthub
//
//  Created by 张鸿燊 on 5/2/2024.
//

import SwiftUI

struct VolumeControlView: View {
    @Binding var volume: Float
    @State private var volumeAdjustStep: Float = 0.1
    
    var body: some View {
        HStack {
            Button {
                volume = minmax(volume - volumeAdjustStep, min: 0, max: 1)
            } label: {
                Image(systemName: volume == 0 ? "speaker.slash.fill" : "speaker.fill")
            }
            .keyboardShortcut(.downArrow, modifiers: [])
            Slider(value: $volume, in: 0...1) {
            }
            Button {
                volume = minmax(volume + volumeAdjustStep, min: 0, max: 1)
            } label: {
                Image(systemName: "speaker.wave.3.fill")
            }
            .keyboardShortcut(.upArrow, modifiers: [])
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
    VolumeControlView(volume: .constant(0.3))
}
