//
//  DevicePickerView.swift
//  Arthub
//
//  Created by 张鸿燊 on 5/3/2024.
//

import SwiftUI
import AVKit

#if canImport(AppKit)
struct DevicePickerView: NSViewRepresentable {
    var player: AVPlayer?
    
    func makeNSView(context: Context) -> NSView {
        let view = AVRoutePickerView()
        
        view.player = player
        view.isRoutePickerButtonBordered = false
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Update the view if needed
    }
}
#elseif canImport(UIKit)
struct DevicePickerView: UIViewRepresentable {
    var player: AVPlayer?
    
    func makeUIView(context: Context) -> UIView {
        let view = AVRoutePickerView()
        #if os(iOS)
        view.prioritizesVideoDevices = true
        #endif
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update the view if needed
    }
}
#endif
