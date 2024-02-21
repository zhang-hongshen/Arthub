//
//  ErrorImageView.swift
//  Arthub
//
//  Created by 张鸿燊 on 18/2/2024.
//

import SwiftUI

struct ErrorImageView: View {
    
    @State var error: Error? = nil
    
    var body: some View {
        Color.gray
            .overlay(alignment: .center) {
                GeometryReader { proxy in
                    Image(systemName: "exclamationmark.circle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: proxy.size.width / 4, height: proxy.size.height / 4)
                    if let err = error {
                        Text(err.localizedDescription)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
        }
        
    }
}
#Preview {
    ErrorImageView()
}
