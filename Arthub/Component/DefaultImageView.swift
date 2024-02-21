//
//  DefaultImageView.swift
//  Arthub
//
//  Created by 张鸿燊 on 18/2/2024.
//

import SwiftUI

struct DefaultImageView: View {
    
    var body: some View {
        GeometryReader { proxy in
            Color.gray
                .overlay {
                    Image(systemName: "photo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: proxy.size.width / 4, height: proxy.size.height / 4)
                }
        }
    }
}



#Preview {
    DefaultImageView()
}
