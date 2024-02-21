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
                case .system:   .dark
                case .light:    .light
                case .dark:     .dark
                }
            }())
                
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

struct ScaleEffectModifier: ViewModifier {
    
    private var scaled : Bool = false
    
    init(_ scaled: Bool) {
        self.scaled = scaled
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scaled ? .defaultSelectedScale : .defaultScale,
                          anchor: .center)
            .animation(.spring(duration: 0.5), value: scaled)
    }
}

extension View {
    
    func cornerRadius(cornerRadius: CGFloat = .defaultCornerRadius) -> some View {
        self.modifier(RoundedRectangleModifier(cornerRadius: cornerRadius))
    }
    
    func applyUserSettings() -> some View {
        self.modifier(SettingsModifier())
    }
    
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, *)
    public func cursor(_ cursor: NSCursor = .pointingHand) -> some View {
        self.modifier(CursorModifier(cursor: cursor))
    }
    
    public func scaleEffect(_ scaled: Bool) -> some View {
        self.modifier(ScaleEffectModifier(scaled))
    }
}


