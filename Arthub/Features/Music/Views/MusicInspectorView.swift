//
//  MusicInspectorView.swift
//  Arthub
//
//  Created by 张鸿燊 on 1/2/2024.
//

import SwiftUI

struct MusicInspectorView: View {
    
    enum Tab: Hashable, CaseIterable {
        case details, artwork, lyrics
        
        var title: LocalizedStringKey {
            switch self {
            case .details: "Details"
            case .artwork: "Artwork"
            case .lyrics: "Lyrics"
            }
        }
    }
    
    @Bindable var song: Song
    /// After the changes are written into the file.
    var onSave: (() -> Void)? = nil
    @State private var fileImporterPresented = false
    @State private var currentTab: Tab = .details
    @State private var error: Error?
    
    var body: some View {
        VStack(spacing: 0) {
            HeaderView()
                .padding()
            
            Picker("", selection: $currentTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            
            Group {
                switch currentTab {
                case .details: DetailsView()
                case .artwork: ArtworkView()
                case .lyrics: LyricsEditView(song: song).padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // The lyrics editor saves on its own.
            if currentTab != .lyrics {
                SaveBar()
            }
        }
        #if !os(tvOS)
        .fileImporter(isPresented: $fileImporterPresented, allowedContentTypes: [.image]) { result in
            switch result {
            case .success(let url): importAlbumCover(url)
            case .failure(let error): print(error.localizedDescription)
            }
        }
        #endif
        .alert(error: $error)
    }
}

extension MusicInspectorView {
    
    @ViewBuilder
    func HeaderView() -> some View {
        HStack(spacing: 12) {
            ArtworkImage(data: song.album.cover, aspectRatio: 1) {
                ImageButton(systemImage: "music.note")
            }
            .frame(width: 64, height: 64)
            .cornerRadius()
            
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title).font(.headline)
                Text(song.artist.name).foregroundStyle(.secondary)
                Text(song.album.title).foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    @ViewBuilder
    func ArtworkView() -> some View {
        VStack(alignment: .leading) {
            Text("Album Artwork")
                .foregroundStyle(.secondary)
            
            ArtworkImage(data: song.album.cover, aspectRatio: 1) {
                ImageButton(systemImage: "music.note", action: { fileImporterPresented = true })
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .cornerRadius()
            #if !os(tvOS)
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first, url.isImage else { return false }
                return importAlbumCover(url)
            }
            #endif
            
            Spacer(minLength: 0)
            
            Button("Add Artwork") {
                fileImporterPresented = true
            }
        }
        .padding()
    }
    
    // Plain SwiftUI layout on purpose: a grouped Form is an NSTableView whose cells host
    // their own NSHostingViews, and resizing the inspector made those cells re-invalidate
    // each other until AppKit threw "more Update Constraints in Window passes than views".
    @ViewBuilder
    func DetailsView() -> some View {
        ScrollView {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                TextRow("Title", \.title)
                TextRow("Artist", \.artist.name)
                TextRow("Composer", \.composer)
                TextRow("Lyricist", \.lyricist)
                TextRow("Arranger", \.arranger)
                TextRow("Album", \.album.title)
                TextRow("Album Artist", \.album.artist.name)
                NumberRow("Track", \.trackNumber)
                NumberRow("Disc Number", \.discNumber)
            }
            .textFieldStyle(.roundedBorder)
            .padding()
        }
        .scrollIndicators(.never)
    }
    
    @ViewBuilder
    func TextRow(_ title: LocalizedStringKey, _ keyPath: ReferenceWritableKeyPath<Song, String>) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
            TextField(text: binding(keyPath), prompt: Text(""), label: { EmptyView() })
        }
    }
    
    @ViewBuilder
    func NumberRow(_ title: LocalizedStringKey, _ keyPath: ReferenceWritableKeyPath<Song, Int?>) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            TextField(value: binding(keyPath), format: .number, prompt: Text(""), label: { EmptyView() })
                .frame(width: 60)
        }
    }
}

extension MusicInspectorView {
    
    /// `@Observable` notifies on every assignment, even an unchanged one. Text fields write their
    /// value back while updating (formatted ones on every pass), so a plain `$song.x` binding
    /// re-invalidated the inspector forever and froze the app as soon as it opened; `edit` skips those.
    private func binding<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<Song, Value>) -> Binding<Value> {
        Binding(get: { song[keyPath: keyPath] }, set: { song.edit(keyPath, to: $0) })
    }
    
    @discardableResult
    func importAlbumCover(_ url: URL) -> Bool {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            song.edit(\.album.cover, to: try Data(contentsOf: url))
        } catch {
            self.error = error
            return false
        }
        return true
    }

    @ViewBuilder
    func SaveBar() -> some View {
        HStack {
            Spacer()
            Button("Save") { saveMetadata() }
                .disabled(song.unsavedTags.isEmpty || song.isSaving)
                .help("Writes the changes into the song file.")
        }
        .padding()
    }

    func saveMetadata() {
        Task {
            do {
                try await song.saveMetadata()
                onSave?()
            } catch {
                self.error = .error(error)
            }
        }
    }
}
