//
//  DeleteButton.swift
//  Arthub
//
//  Created by 张鸿燊 on 2/7/25.
//


import SwiftUI

struct DeleteButton: View {
    
    var action: () -> Void = {}
    
    var body: some View {
        Button("Delete", systemImage: "trash", role: .destructive) {
            action()
        }
    }
}

#Preview {
    DeleteButton()
}
