//
//  GeneralView.swift
//  Arthub
//
//  Created by 张鸿燊 on 3/2/2024.
//

import SwiftUI


enum Appearance: String, CaseIterable, Hashable {
    case system = "system"
    case light = "light"
    case dark = "dark"
}

struct GeneralView: View {
    @AppStorage(UserDefaults.Settings.appearance.rawValue)
    private var appearance: Appearance = .system
    
    private var appearanceWidth: CGFloat = 200
    
    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline) {
            
            GridRow {
                Text("settings.appearance").gridColumnAlignment(.trailing)
                Picker("", selection: $appearance) {
                    ForEach(Appearance.allCases, id: \.self) {appearance in
                        Text(appearance.rawValue).tag(appearance)
                    }
                }
                .frame(width: appearanceWidth)
            }
            
        }
        .font(.title3)
    }
}

#Preview {
    GeneralView()
}
