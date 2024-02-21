//
//  StorageView.swift
//  Arthub
//
//  Created by 张鸿燊 on 5/2/2024.
//

import SwiftUI


enum StorageType {
    case local, remote
}

struct StorageView: View {
    
    @State private var storageType: StorageType = .local

    var body: some View {
        
        AutoWidthTabView(selection: $storageType) {
            
            LocalStorageView().tag(StorageType.local)
                .tabItem {
                    Text("settings.storage.local")
                }
            
            RemoteStorageView().tag(StorageType.remote)
                .tabItem {
                    Text("settings.storage.remote")
                }
        }
        
    }
}

#Preview {
    StorageView()
}
