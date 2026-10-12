//
//  WindowState.swift
//  Arthub
//
//  Created by 张鸿燊 on 8/2/2024.
//

import SwiftUI

/// Hides the sidebar while a video player is open, and brings it back as it was afterwards.
@Observable class WindowState {

    var columnVisibility: NavigationSplitViewVisibility = .all
    var toolbarRemove: ToolbarDefaultItemKind? = nil

    private var visibilityBeforeFullScreen: NavigationSplitViewVisibility = .all

    func enterFullScreen() {
        visibilityBeforeFullScreen = columnVisibility
        columnVisibility = .detailOnly
        toolbarRemove = .sidebarToggle
    }

    func exitFullScreen() {
        columnVisibility = visibilityBeforeFullScreen
        toolbarRemove = nil
    }
}
