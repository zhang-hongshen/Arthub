//
//  ErrorView.swift
//  Arthub
//
//  Created by 张鸿燊 on 18/2/2024.
//

import SwiftUI

struct ErrorView: View {
    
    @State var error: Error? = nil
    
    var body: some View {
        ContentUnavailableView("Error",
                               systemImage: "exclamationmark.circle",
                               description: Text(error?.localizedDescription ?? ""))
    }
}

#Preview {
    ErrorView(error: nil)
}
