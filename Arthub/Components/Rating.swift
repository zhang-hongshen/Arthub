//
//  Rating.swift
//  Arthub
//
//  Created by 张鸿燊 on 28/2/2024.
//

import SwiftUI

struct Rating: View {
    
    @State var value: Double
    @State var total: Double
    
    var body: some View {
        HStack(alignment: .center, spacing: 5) {
            Rectangle()
                .overlay {
                    GeometryReader { proxy in
                        Rectangle()
                            .fill(.accent.gradient)
                            .frame(width: proxy.size.width * value / total)
                    }
                }
                .mask(alignment: .leading) {
                    Image(systemName: "star.fill")
                        .resizable()
                }
                .aspectRatio(contentMode: .fit)
            
            Text(value.formatted(.number.precision(.fractionLength(1))))
        }
    }
}

#Preview {
    Rating(value: 7, total: 10)
}
