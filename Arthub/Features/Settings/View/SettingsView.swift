//
//  SettingsView.swift
//  Arthub
//
//  Created by 张鸿燊 on 3/2/2024.
//

import SwiftUI

enum AppSettingsTab: String, CaseIterable, Identifiable {
    case general
    var id: Self { self }
}

struct SettingsView: View {
    
    @State private var selectedTab: AppSettingsTab = .general
    
    var body: some View {
        #if os(iOS)
        SettingsListView()
        #else
        SettingsTabView()
        #endif
    }
}

extension SettingsView {
    
    @ViewBuilder
    func SettingsTabView() -> some View {
        TabView(selection: $selectedTab) {
            Group {
                GeneralView().tag(AppSettingsTab.general)
                    .tabItem {
                        Image(systemName: "gearshape")
                        Text("General")
                    }
            }
            .safeAreaPadding()
        }
        .autoSize()
    }
    
    @ViewBuilder
    func SettingsListView() -> some View {
        Form {
            NavigationLink("General") {
                GeneralView()
            }
        }
    }
}


#Preview {
    SettingsView()
}
