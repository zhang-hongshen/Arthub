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
    
    @AppStorage(UserDefaults.language)
    private var language: Language = .system

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
            Picker("Language", selection: $language) {
                Text("System").tag(Language.system)
                // Language names are shown in their own language, never translated.
                Text(verbatim: "English").tag(Language.english)
                Text(verbatim: "简体中文").tag(Language.simplifiedChinese)
                Text(verbatim: "繁體中文").tag(Language.traditionalChinese)
            }
            .onChange(of: language) { _, newValue in
                newValue.applyToBundle()
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
