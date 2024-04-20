//
//  GeneralView.swift
//  Arthub
//
//  Created by 张鸿燊 on 3/2/2024.
//

import SwiftUI

struct GeneralView: View {
    @AppStorage(UserDefaults.appearance)
    private var appearance: Appearance = .system

    var body: some View {
        MainView()
    }
}

extension GeneralView {
    
    @ViewBuilder
    func MainView() -> some View {
        Form {
            Picker("Appearance", selection: $appearance) {
                Text("System").tag(Appearance.system)
                Text("Light").tag(Appearance.light)
                Text("Dark").tag(Appearance.dark)
            }
        }
        #if !os(iOS)
        .fixedSize()
        #endif
        #if !os(macOS)
        .pickerStyle(.navigationLink)
        #endif
    }
}

#Preview {
    GeneralView()
}
