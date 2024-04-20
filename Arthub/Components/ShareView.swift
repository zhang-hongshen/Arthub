//
//  ShareView.swift
//  Arthub
//
//  Created by 张鸿燊 on 7/3/2024.
//

import SwiftUI
import MultipeerConnectivity

#if canImport(AppKit)
struct ShareView: NSViewControllerRepresentable {
    
    func makeNSViewController(context: Context) -> MCBrowserViewController {
        
        //let shareService = ShareService()
        let controler = MCBrowserViewController(serviceType: "serviceType", session: MCSession(peer: .init(displayName: "displayName")))
        
        return controler
        
    }
    
    func updateNSViewController(_ nsViewController: MCBrowserViewController, context: Context) {
        
    }
}
#elseif canImport(UIKit)
struct ShareView: UIViewControllerRepresentable {
    
    func makeUIViewController(context: Context) -> MCBrowserViewController {
        
        //let shareService = ShareService()
        let controler = MCBrowserViewController(serviceType: "serviceType", session: MCSession(peer: .init(displayName: "displayName")))
        
        return controler
        
    }
    
    func updateUIViewController(_ uiViewController: MCBrowserViewController, context: Context) {
        
    }
}
#endif

#Preview {
    ShareView()
}
