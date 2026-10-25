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
            Section {
                LabeledContent("Appearance") {
                    HStack(spacing: 10) {
                        AppearanceOption("System", value: .system)
                        AppearanceOption("Light", value: .light)
                        AppearanceOption("Dark", value: .dark)
                    }
                }
            }
            Section {
                Picker("Language", selection: $language) {
                    Text("System").tag(Language.system)
                    // Language names are shown in their own language, never translated.
                    Text(verbatim: "English").tag(Language.english)
                    Text(verbatim: "简体中文").tag(Language.simplifiedChinese)
                    Text(verbatim: "繁體中文").tag(Language.traditionalChinese)
                }
                #if !os(macOS)
                .pickerStyle(.navigationLink)
                #endif
                .onChange(of: language) { _, newValue in
                    newValue.applyToBundle()
                }
            }
        }
        .formStyle(.grouped)
        #if os(macOS)
        .frame(width: 480, height: 360)
        #endif
        .navigationTitle("General")
    }

    /// A selectable card with a small window picture, like the macOS Appearance setting.
    @ViewBuilder
    func AppearanceOption(_ title: LocalizedStringKey, value: Appearance) -> some View {
        let selected = appearance == value
        Button {
            appearance = value
        } label: {
            VStack(spacing: 6) {
                switch value {
                case .system:
                    // Light on the left half, dark on the right half.
                    WindowThumbnail(dark: false)
                        .overlay {
                            WindowThumbnail(dark: true)
                                .mask(alignment: .trailing) {
                                    Rectangle().frame(width: 40)
                                }
                        }
                case .light:
                    WindowThumbnail(dark: false)
                case .dark:
                    WindowThumbnail(dark: true)
                }
                Text(title)
                    .font(.callout)
            }
            .padding(6)
            .background(selected ? Color.accentColor.opacity(0.15) : .clear,
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(selected ? Color.accentColor : Color.secondary.opacity(0.3))
            }
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

/// A tiny drawing of an app window: traffic lights, a sidebar and some text lines.
struct WindowThumbnail: View {
    let dark: Bool

    var body: some View {
        let background = dark ? Color(white: 0.17) : Color(white: 0.97)
        let sidebar = dark ? Color(white: 0.23) : Color(white: 0.9)
        let line = dark ? Color(white: 0.45) : Color(white: 0.75)

        HStack(spacing: 0) {
            Lines(color: line)
                .frame(width: 30)
                .background(sidebar)
            Lines(color: line)
                .background(background)
        }
        .overlay(alignment: .top) {
            HStack(spacing: 3) {
                Circle().fill(.red)
                Circle().fill(line)
                Circle().fill(line)
            }
            .frame(height: 5)
            .padding(.top, 5)
        }
        .frame(width: 80, height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 0.5)
        }
    }

    private func Lines(color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Capsule().fill(color).frame(width: 14, height: 2)
            Capsule().fill(color).frame(height: 1.5)
            Capsule().fill(color).frame(width: 18, height: 1.5)
        }
        .padding(.horizontal, 5)
        .padding(.top, 17)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    GeneralView()
}
