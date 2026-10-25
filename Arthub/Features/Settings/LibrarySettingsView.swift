//
//  LibrarySettingsView.swift
//  Arthub
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

/// The folders Arthub scans, including the default Movies and Music folders a new install starts with.
struct LibrarySettingsView: View {

    @AppStorage(UserDefaults.library)
    private var libraries: [String] = []

    @State private var libraryIndex = LibraryViewModel.shared
    @State private var fileImporterPresented = false
    @State private var serverSheetPresented = false
    @State private var folderError: String?

    var body: some View {
        Form {
            Section {
                if libraries.isEmpty {
                    Text("No Folders")
                        .foregroundStyle(.secondary)
                }
                ForEach(libraries, id: \.self) { library in
                    LibraryRow(library)
                }
                .onDelete { libraries.remove(atOffsets: $0) }
            } footer: {
                Text("Arthub scans these folders for movies, TV shows and music.")
            }
            Section {
                Button("Add Folder…", systemImage: "plus") {
                    fileImporterPresented = true
                }
                #if os(macOS)
                Button("Connect to Server…", systemImage: "server.rack") {
                    serverSheetPresented = true
                }
                #endif
            }
        }
        .formStyle(.grouped)
        #if os(macOS)
        .frame(width: 480, height: 360)
        #endif
        .navigationTitle("Library")
        .fileImporter(isPresented: $fileImporterPresented, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url):
                addLibrary(url)
            case .failure(let error):
                folderError = error.localizedDescription
            }
        }
        .sheet(isPresented: $serverSheetPresented) {
            AddServerView { library in
                if libraries.contains(library) {
                    Task { await libraryIndex.refresh() }
                } else {
                    libraries.append(library)
                }
            }
        }
        .alert("Unable to Add Folder", isPresented: Binding(
            get: { folderError != nil }, set: { if !$0 { folderError = nil } })) {
            Button("OK") { folderError = nil }
        } message: { Text(folderError ?? "") }
    }
}

extension LibrarySettingsView {

    @ViewBuilder
    func LibraryRow(_ library: String) -> some View {
        HStack {
            Label {
                VStack(alignment: .leading) {
                    Text(libraryIndex.displayName(for: library))
                    #if os(macOS)
                    if RemoteFolder.isRemote(library) {
                        Text(library)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else if let url = libraryIndex.folderURL(for: library) {
                        Text((url.path(percentEncoded: false) as NSString).abbreviatingWithTildeInPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    #endif
                }
            } icon: {
                Image(systemName: libraryIndex.offlineLibraries.contains(library)
                      ? "externaldrive.badge.exclamationmark"
                      : RemoteFolder.isRemote(library) ? "server.rack" : "folder")
            }
            #if os(macOS)
            Spacer()
            Button("Remove", systemImage: "minus.circle") { remove(library) }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Remove")
            #endif
        }
        .contextMenu {
            #if canImport(AppKit)
            Button("Reveal in Finder", systemImage: "folder") {
                if let url = libraryIndex.folderURL(for: library) {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
                }
            }
            #endif
            DeleteButton { remove(library) }
        }
    }

    func remove(_ library: String) {
        libraries.removeAll { $0 == library }
        if RemoteFolder.isRemote(library) { RemoteFolder.forget(library) }
    }

    func addLibrary(_ url: URL) {
        // fileImporter hands over a security-scoped URL; keep its absolute
        // form and skip folders already in the list.
        let entry = url.absoluteString
        do {
            try libraryIndex.rememberFolder(url)
            if libraries.contains(entry) {
                Task { await libraryIndex.refresh() }
            } else {
                libraries.append(entry)
            }
        } catch { folderError = error.localizedDescription }
    }
}

/// Connects an SMB or WebDAV folder, like Finder's Connect to Server.
private struct AddServerView: View {

    let onAdd: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var user = ""
    @State private var password = ""
    @State private var isConnecting = false
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                TextField("Server Address", text: $address, prompt: Text(verbatim: "smb://nas.local/Media"))
                TextField("User Name", text: $user, prompt: Text("Guest"))
                SecureField("Password", text: $password)
            } footer: {
                VStack(alignment: .leading) {
                    Text("SMB: smb://server/share/folder. WebDAV: https://server:port/folder.")
                    if let error {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .disabled(isConnecting)
        .frame(width: 420)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                if isConnecting {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Connect") { Task { await connect() } }
                        .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    func connect() async {
        guard let library = RemoteFolder.library(address: address, user: user) else {
            error = RemoteFolderError.badAddress.localizedDescription
            return
        }
        isConnecting = true
        defer { isConnecting = false }
        do {
            try await RemoteFolder.connect(library, password: password)
            onAdd(library)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#Preview {
    LibrarySettingsView()
}
