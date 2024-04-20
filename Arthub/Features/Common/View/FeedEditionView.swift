//
//  FeedEditionView.swift
//  Arthub
//
//  Created by 张鸿燊 on 15/3/2024.
//

import SwiftUI
import FeedKit

struct FeedEditionView: View {
    
    fileprivate enum Field: Hashable {
        case title, address
    }
    
    @Bindable var feed: FeedDetail
    
    @FocusState private var focusedField: Field?
    @State private var error: ArthubError? = nil
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(alignment: .center) {
            HStack(alignment: .center, spacing: 3) {
                Text("Add Subscribe Link")
                    .font(.headline)
            }
            
            Form {
                LabeledContent("Title") {
                    TextField("", text: $feed.title, prompt: Text("Optional"))
                }
                LabeledContent("Address") {
                    TextField("", text: $feed.url, prompt: Text("https://example.com"))
                        .focused($focusedField, equals: .address)
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
                        try await CachedDataHandler.shared.insert(feed)
                        dismiss.callAsFunction()
                    }
                } label: { Text("Finish") }
            }
        }
        .alert(error: $error)
    }
}


extension FeedEditionView {
    
    func checkRequiredField() -> Bool {
        if feed.url.isEmpty {
            focusedField = .address; return false
        }
        return true
    }
    
}

