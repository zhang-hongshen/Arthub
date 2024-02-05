//
//  SettingsView.swift
//  Arthub
//
//  Created by 张鸿燊 on 3/2/2024.
//

import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general, keybindings, locations
    var id: Self { self }
}

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralView().tag(SettingsTab.general)
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("settings.tab.general")
                }
            KeybindingView().tag(SettingsTab.keybindings)
                .tabItem {
                    Image(systemName: "keyboard")
                    Text("settings.tab.keybindings")
                }
            LocationView().tag(SettingsTab.locations)
                .tabItem {
                    Image(systemName: "externaldrive")
                    Text("settings.tab.locations")
                }
        }
        .frame(width: 500, height: 500)
    }
}

#Preview {
    SettingsView()
}
