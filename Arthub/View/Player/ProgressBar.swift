//
//  ProgressBar.swift
//  Arthub
//
//  Created by 张鸿燊 on 5/2/2024.
//

import SwiftUI

struct ProgressBar: View {
    @Binding var value: TimeInterval
    @Binding var total: TimeInterval
    @State var format: NSCalendar.Unit
    @State var onEditingChanged : (Bool) -> Void = { _ in }
    
    var body: some View {
        HStack {
            Text(value.formatted(format))
            Slider(value: $value, in: 0...total) { newValue in
                onEditingChanged(newValue)
            }
            Text(total.formatted(format))
        }
    }
}

#Preview {
    ProgressBar(value: .constant(0), total: .constant(10), format: [.minute, .second])
}
