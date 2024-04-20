//
//  WindowState.swift
//  Arthub
//
//  Created by 张鸿燊 on 8/2/2024.
//

import Foundation
import SwiftUI

@Observable class WindowState {
    
    var columnVisibility: NavigationSplitViewVisibility {
        return columnVisibilitys.last ?? .all
    }
    
    var toolbarRemove: ToolbarDefaultItemKind? = .none
    
    private var columnVisibilitys: [NavigationSplitViewVisibility] = [.all]
    private let semaphore = DispatchSemaphore(value: 1)
    
}

extension WindowState {
    
    func enterFullScreen() {
        semaphore.wait()
        defer { semaphore.signal() }
        columnVisibilitys.append(.detailOnly)
        toolbarRemove = .sidebarToggle
    }
    
    func exitFullScreen() {
        semaphore.wait()
        defer { semaphore.signal() }
        if columnVisibilitys.count > 1 {
            columnVisibilitys.removeLast()
        }
        toolbarRemove = .none
    }
    
    func setColumnVisibility( _ visibility: NavigationSplitViewVisibility) {
        semaphore.wait()
        defer { semaphore.signal() }
        columnVisibilitys[columnVisibilitys.endIndex - 1] = visibility
    }
}

