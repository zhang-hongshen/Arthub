//
//  WindowState.swift
//  Arthub
//
//  Created by 张鸿燊 on 8/2/2024.
//

import Foundation
import SwiftUI
import DequeModule

@Observable
class WindowState {
    
    var columnVisibility: NavigationSplitViewVisibility {
        return columnVisibilitys.last ?? .all
    }
    
    private var columnVisibilitys: Deque<NavigationSplitViewVisibility> = [.all]
    
    private let semaphore = DispatchSemaphore(value: 1)

}

extension WindowState {
    func setColumnVisibility( _ visibility: NavigationSplitViewVisibility) {
        semaphore.wait()
        defer { semaphore.signal() }
        columnVisibilitys[columnVisibilitys.endIndex - 1] = visibility
    }

    func push( _ visibility: NavigationSplitViewVisibility) {
        semaphore.wait()
        defer { semaphore.signal() }
        columnVisibilitys.append(visibility)
    }
    
    func pop() {
        semaphore.wait()
        defer { semaphore.signal() }
        if columnVisibilitys.count > 1 {
            columnVisibilitys.removeLast()
        }
    }
}

