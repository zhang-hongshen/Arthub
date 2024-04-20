//
//  Shape.swift
//  shelf
//
//  Created by 张鸿燊 on 31/1/2024.
//
import SwiftUI

struct RoundedRectangleModifier: ViewModifier {
    let cornerRadius: CGFloat

    init(cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

struct SettingsModifier: ViewModifier {
    
    @AppStorage(UserDefaults.appearance)
    private var apperance = Appearance.system
    
    func body(content: Content) -> some View {
        content
            .preferredColorScheme({
                switch apperance {
                case .system:   nil
                case .light:    .light
                case .dark:     .dark
                }
            }())
    }
}

struct ScaleEffectModifier: ViewModifier {
    
    private var scaled : Bool = false
    
    init(_ scaled: Bool) {
        self.scaled = scaled
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scaled ? Default.selectedScale : Default.scale,
                         anchor: .center)
            .animation(.spring(duration: 0.5), value: scaled)
    }
}

struct FocusEffectModifier: ViewModifier {
    
    func body(content: Content) -> some View {
        content
            .focusable()
            .focusEffectDisabled()
    }
}

struct AlertModifier: ViewModifier {
    
    @Binding var error: ArthubError?
    
    func body(content: Content) -> some View {
        content
            .alert(error?.localizedDescription ?? "",
                   isPresented: Binding(
                    get: { error != nil },
                    set: { _ in })) {
                Button("OK") {
                    error = nil
                }
            }
    }
}

@available(iOS 13.4, macOS 10.15, *)
struct HoverEffectModifier: ViewModifier {
    
    @State private var isHovering = false
    
    func body(content: Content) -> some View {
        content.onHover { isHovering = $0 }
            .padding(10)
            .background {
                if isHovering {
                    RoundedRectangle().fill(.selection)
                }
            }
    }
}

extension View {
    
    func cornerRadius(_ cornerRadius: CGFloat = Default.cornerRadius) -> some View {
        self.modifier(RoundedRectangleModifier(cornerRadius: cornerRadius))
    }
    
    func applyUserSettings() -> some View {
        self.modifier(SettingsModifier())
    }
    
    func scaleEffect(_ scaled: Bool = true) -> some View {
        self.modifier(ScaleEffectModifier(scaled))
    }
    
    func focusEffect() -> some View {
        self.modifier(FocusEffectModifier())
    }
    
    func alert(error: Binding<ArthubError?>) -> some View {
        self.modifier(AlertModifier(error: error))
    }
    
    func transparentEffect() -> some View {
        self.background {
            Rectangle()
                .fill(.thinMaterial.opacity(0.4))
                .blur(radius: 6, opaque: true)
                .shadow()
                .background(.secondary.opacity(0.2))
        }
    }
    
    func shadow() -> some View {
        self.shadow(radius: Default.shadowRadius)
    }
    
    #if !os(tvOS)
    func hoverEffect() -> some View {
        self.modifier(HoverEffectModifier())
    }
    #endif
    
}

#if canImport(AppKit)

extension View {
    func hideToolbarWhenFullscreen() -> some View {
        self.modifier(HideToolbarWhenFullscreenModifier())
    }
}

struct CursorModifier: ViewModifier {
    
    var cursor: NSCursor = .pointingHand
    
    func body(content: Content) -> some View {
        content.onContinuousHover(coordinateSpace: .local) { phase in
            switch phase {
            case .active(_):
                guard NSCursor.current != cursor else {
                    return
                }
                DispatchQueue.main.async {
                    cursor.push()
                }
            case .ended:
                DispatchQueue.main.async {
                    NSCursor.pop()
                }
            }
        }
                
    }
}

struct HideToolbarWhenFullscreenModifier: ViewModifier {
    
    private var customWindowDelegate = CustomWindowDelegate()
    
    func body(content: Content) -> some View {
        content
            .background {
                HostingWindowFinder { window in
                    guard let window else { return }
                    window.delegate = customWindowDelegate
                    window.titlebarAppearsTransparent = true
                }
            }
    }
}

class CustomWindowDelegate: NSObject, NSWindowDelegate {
    override init() {
        super.init()
    }
    
    func window(_ window: NSWindow, willUseFullScreenPresentationOptions proposedOptions: NSApplication.PresentationOptions = []) -> NSApplication.PresentationOptions {
        return [.autoHideToolbar, .autoHideMenuBar, .fullScreen]
    }
}

struct HostingWindowFinder: NSViewRepresentable {
    var callback: (NSWindow?) -> ()
    
    func makeNSView(context: Self.Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { self.callback(view.window) }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { self.callback(nsView.window) }
    }
}
#endif
