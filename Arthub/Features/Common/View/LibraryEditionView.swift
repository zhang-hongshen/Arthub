//
//  LibraryEditionView.swift
//  Arthub
//
//  Created by 张鸿燊 on 21/3/2024.
//

import SwiftUI

struct LibraryEditionView: View {
    
    fileprivate enum Field: Hashable {
        case title, address
        case username, password
    }
    
    @Bindable var library: LibraryDetail
    
    @FocusState private var focusedField: Field?
    @State private var error: ArthubError? = nil
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(alignment: .center) {
            Text("Add Network Share").font(.headline)
            
            Form {
                LabeledContent("Title") {
                    TextField("", text: $library.title, prompt: Text("Optional"))
                }
                
                Picker("Protocol", selection: $library.protocolType) {
                    ForEach(ProtocolType.allCases) {
                        Text($0.localizedName).tag($0)
                    }
                }
                
                LabeledContent("Address") {
                    TextField("", text: $library.url, prompt: Text("example.com"))
                        .focused($focusedField, equals: .address)
                }
                
                LabeledContent("Username") {
                    TextField("", text: $library.username, prompt: Text("Username"))
                        .focused($focusedField, equals: .username)
                }
                
                LabeledContent("Password") {
                    TextField("", text: $library.username, prompt: Text("Password"))
                        .focused($focusedField, equals: .password)
                }
                
            }
        }
        .safeAreaPadding()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", role: .cancel, action: dismiss.callAsFunction)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    guard checkRequiredField() else { return }
                    Task {
                        try await CachedDataHandler.shared.insert(library)
                        dismiss.callAsFunction()
                    }
                } label: { Text("Finish") }
            }
        }
        .alert(error: $error)
    }
}


extension LibraryEditionView {
    
    func checkRequiredField() -> Bool {
        if library.url.isEmpty {
            focusedField = .address; return false
        }
        return true
    }
    
}
