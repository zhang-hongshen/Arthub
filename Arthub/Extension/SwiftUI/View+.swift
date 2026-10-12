//
//  Shape.swift
//  shelf
//
//  Created by 张鸿燊 on 31/1/2024.
//
import SwiftUI

extension View {

    func cornerRadius(_ cornerRadius: CGFloat = Default.cornerRadius) -> some View {
        clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    /// The appearance and language picked in Settings.
    func applyUserSettings() -> some View {
        modifier(UserSettingsModifier())
    }

    /// Lets the view take keyboard focus without drawing a focus ring.
    func focusEffect() -> some View {
        focusable().focusEffectDisabled()
    }

    /// Shows `error` in an alert until OK is pressed.
    func alert(error: Binding<Error?>) -> some View {
        alert(error.wrappedValue?.localizedDescription ?? "",
              isPresented: Binding(get: { error.wrappedValue != nil },
                                   set: { if !$0 { error.wrappedValue = nil } })) {
            Button("OK") {}
        }
    }

    func transparentEffect() -> some View {
        background {
            Rectangle()
                .fill(.thinMaterial.opacity(0.4))
                .blur(radius: 6, opaque: true)
                .shadow()
                .background(.secondary.opacity(0.2))
        }
    }

    func shadow() -> some View {
        shadow(radius: Default.shadowRadius)
    }

    #if !os(tvOS)
    /// Highlights the view while the pointer is over it.
    func hoverEffect() -> some View {
        modifier(HoverEffectModifier())
    }
    #endif
}

private struct UserSettingsModifier: ViewModifier {

    @AppStorage(UserDefaults.appearance)
    private var appearance = Appearance.system

    @AppStorage(UserDefaults.language)
    private var language = Language.system

    func body(content: Content) -> some View {
        content
            .environment(\.locale, language.locale)
            #if canImport(AppKit)
            // preferredColorScheme(nil) leaves macOS windows in the last forced appearance
            // instead of following the system again, so set the app's appearance instead.
            .onChange(of: appearance, initial: true) {
                NSApp.appearance = switch appearance {
                case .system:   nil
                case .light:    NSAppearance(named: .aqua)
                case .dark:     NSAppearance(named: .darkAqua)
                }
            }
            #else
            .preferredColorScheme({
                switch appearance {
                case .system:   nil
                case .light:    .light
                case .dark:     .dark
                }
            }())
            #endif
    }
}

private struct HoverEffectModifier: ViewModifier {

    @State private var isHovering = false

    func body(content: Content) -> some View {
        content.onHover { isHovering = $0 }
            .padding(10)
            .background {
                if isHovering {
                    RoundedRectangle(cornerRadius: Default.cornerRadius).fill(.selection)
                }
            }
    }
}

#if canImport(AppKit)

extension View {
    /// Hides the toolbar and menu bar in full screen until the pointer reaches the top of the screen.
    func hideToolbarWhenFullscreen() -> some View {
        background {
            HostingWindowFinder { window in
                window?.delegate = FullScreenWindowDelegate.shared
                window?.titlebarAppearsTransparent = true
            }
        }
    }
}

private class FullScreenWindowDelegate: NSObject, NSWindowDelegate {

    static let shared = FullScreenWindowDelegate()

    func window(_ window: NSWindow, willUseFullScreenPresentationOptions proposedOptions: NSApplication.PresentationOptions = []) -> NSApplication.PresentationOptions {
        [.autoHideToolbar, .autoHideMenuBar, .fullScreen]
    }
}

/// Hands the view's window to `callback` once the view is in one.
private struct HostingWindowFinder: NSViewRepresentable {
    var callback: (NSWindow?) -> ()

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { callback(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { callback(nsView.window) }
    }
}
#endif
