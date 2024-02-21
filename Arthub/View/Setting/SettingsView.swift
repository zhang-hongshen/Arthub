//
//  SettingsView.swift
//  Arthub
//
//  Created by 张鸿燊 on 3/2/2024.
//

import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general, storage
    var id: Self { self }
}

struct SettingsView: View {
    
    @State private var selectedTab: SettingsTab = .general
    
    var body: some View {
        AutoWidthTabView(selection: $selectedTab) {

            GeneralView().tag(SettingsTab.general)
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("settings.general")
                }
            
            StorageView().tag(SettingsTab.storage)
                .tabItem {
                    Image(systemName: "externaldrive")
                    Text("settings.storage")
                }
            
        }
        
        .safeAreaPadding(10)
    }
}


#Preview {
    SettingsView()
}
