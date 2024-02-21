//
//  DefaultAvatarView.swift
//  Arthub
//
//  Created by 张鸿燊 on 18/2/2024.
//

import SwiftUI

struct DefaultAvatarView: View {
    
    var body: some View {
        GeometryReader { proxy in
            Color.gray
                .overlay {
                    Image(systemName: "person.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: proxy.size.width / 4, height: proxy.size.height / 4)
                }
        }
    }
}

#Preview {
    DefaultAvatarView()
}
