import SwiftUI
import AVKit
#if os(macOS)
import AppKit
#endif

struct LibraryView: View {
    let library: String?
    var directory: URL? = nil
    var unmatchedOnly = false

    @State private var index = LibraryViewModel.shared
    @State private var search = ""
    @State private var folders: [URL] = []
    @State private var visibleFiles: [LibraryFile] = []
    @State private var matchingFile: LibraryFile?
    @State private var playingFile: LibraryFile?

    private var root: URL? { directory ?? library.flatMap { index.folderURL(for: $0) } }

    var body: some View {
        List {
            if let library, index.offlineLibraries.contains(library) {
                Label("Folder offline or access unavailable. Saved media is kept.", systemImage: "externaldrive.badge.exclamationmark")
                    .foregroundStyle(.secondary)
            }
            if let error = index.storageError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
            ForEach(folders, id: \.self) { folder in
                NavigationLink {
                    LibraryView(library: library, directory: folder)
                } label: {
                    Label(folder.lastPathComponent, systemImage: "folder")
                }
            }
            ForEach(visibleFiles) { file in
                LibraryFileRow(file: file, isOffline: index.offlineLibraries.contains(file.library),
                               matchDisabled: index.isScanning || index.isMatching,
                               play: { playingFile = file }, match: { matchingFile = file })
            }
            if folders.isEmpty && visibleFiles.isEmpty {
                ContentUnavailableView {
                    Label(unmatchedOnly ? "No Unmatched Media" : "No Media", systemImage: "folder")
                } description: {
                    Text(index.isScanning ? "Scanning folders…" : "Add a media folder or change your search.")
                }
            }
        }
        .navigationTitle(unmatchedOnly ? String(localized: "Unmatched Media") : root?.lastPathComponent ?? String(localized: "All Files"))
        .searchable(text: $search)
        .toolbar {
            ToolbarItemGroup {
                Button { Task { await index.refresh() } } label: {
                    if index.isScanning {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(index.isScanning || index.isMatching)
                Button("Retry Unmatched", systemImage: "arrow.triangle.2.circlepath") {
                    Task { await index.retryUnmatched(library: library) }
                }
                .disabled(index.isScanning || index.isMatching)
            }
        }
        .sheet(item: $matchingFile) { file in LibraryMatchView(file: file) }
        .sheet(item: $playingFile) { file in LibraryFilePlayer(file: file) }
        .onChange(of: index.revision, initial: true) { _, _ in updateRows() }
        .onChange(of: search) { _, _ in updateRows() }
    }

    private func updateRows() {
        var directories: Set<URL> = []
        var items: [LibraryFile] = []
        for file in index.files {
            if let library, file.library != library {
                guard let source = index.folderURL(for: library),
                      file.fileURL.standardizedFileURL.pathComponents.starts(with: source.standardizedFileURL.pathComponents) else { continue }
            }
            guard !unmatchedOnly || (file.fileURL.isVideo && !file.isMatched) else { continue }
            if !search.isEmpty {
                guard file.title.localizedStandardContains(search) ||
                    file.fileURL.lastPathComponent.localizedStandardContains(search) else { continue }
            }
            if let root, !unmatchedOnly && search.isEmpty {
                let base = root.standardizedFileURL.pathComponents
                let path = file.fileURL.standardizedFileURL.pathComponents
                guard path.starts(with: base) else { continue }
                if path.count > base.count + 1 {
                    directories.insert(root.appending(path: path[base.count], directoryHint: .isDirectory))
                    continue
                }
            }
            items.append(file)
        }
        folders = directories.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        visibleFiles = items
    }
}

private struct LibraryFileRow: View {
    let file: LibraryFile
    let isOffline: Bool
    let matchDisabled: Bool
    let play: () -> Void
    let match: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            LibraryThumbnail(url: file.fileURL, artwork: file.artwork, available: file.isAvailable)
                .frame(width: 80, height: 52).clipped().cornerRadius(6)
            VStack(alignment: .leading, spacing: 4) {
                Text(file.title).lineLimit(1)
                if file.title != file.fileURL.lastPathComponent {
                    Text(file.fileURL.lastPathComponent).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                HStack {
                    if !file.isAvailable {
                        Label(isOffline ? "Offline" : "File Missing", systemImage: "exclamationmark.circle")
                    } else if file.fileURL.isVideo && !file.isMatched {
                        Text("Unmatched")
                    }
                    Text(ByteCountFormatter.string(fromByteCount: Int64(file.size), countStyle: .file))
                }
                .font(.caption).foregroundStyle(.secondary)
                if let error = file.error {
                    Text(error).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer()
            if file.fileURL.isVideo {
                Button("Match Metadata", systemImage: "square.and.pencil", action: match)
                    .labelStyle(.iconOnly).disabled(matchDisabled)
            }
            Button("Play", systemImage: "play.fill", action: play)
                .labelStyle(.iconOnly).disabled(!file.isAvailable)
        }
        .buttonStyle(.borderless)
        .contextMenu {
            Button("Play", systemImage: "play.fill", action: play).disabled(!file.isAvailable)
            if file.fileURL.isVideo {
                Button("Match Metadata", systemImage: "square.and.pencil", action: match).disabled(matchDisabled)
            }
            #if os(macOS)
            Button("Reveal in Finder", systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting([file.fileURL])
            }.disabled(!file.isAvailable)
            #endif
        }
    }
}

private struct LibraryThumbnail: View {
    let url: URL
    let artwork: URL?
    let available: Bool
    @State private var thumbnail: CGImage?

    var body: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            if let artwork {
                ArtworkImage(url: artwork) { Image(systemName: "film") }.id(artwork)
            } else if let thumbnail {
                Image(decorative: thumbnail, scale: 1).resizable().scaledToFill()
            } else {
                Image(systemName: url.isVideo ? "film" : "music.note").foregroundStyle(.secondary)
            }
        }
        .task(id: available) {
            guard available, artwork == nil, url.isVideo else { return }
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 240, height: 160)
            thumbnail = try? await generator.image(at: .zero).image
        }
    }
}

private struct LibraryFilePlayer: View {
    let file: LibraryFile
    @Environment(\.dismiss) private var dismiss
    @Environment(ArthubVideoPlayer.self) private var player
    @Environment(ArthubAudioPlayer.self) private var audioPlayer
    @State private var metrics: UserMetrics?
    @State private var currentTime: TimeInterval = 0
    @State private var ready = false
    @State private var error: String?

    var body: some View {
        VStack {
            HStack {
                Text(file.title).font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }.padding()
            if let error {
                Text(error).foregroundStyle(.red).padding()
            } else if ready {
                VideoPlayerView(currentTime: $currentTime)
            } else { ProgressView() }
        }
        .frame(minWidth: 400, minHeight: 300)
        .task {
            do {
                guard try await AVURLAsset(url: file.fileURL).load(.isPlayable) else {
                    error = String(localized: "This file cannot be played by the current player.")
                    return
                }
                if let id = file.movie?.id ?? file.episode?.id {
                    metrics = try await UserMetrics.getByTMDbID(id)
                }
                try Task.checkCancellation()
                currentTime = metrics?.currentTime ?? 0
                audioPlayer.optOut()
                player.optOut()
                player.preloadItems(playableAssets: [NowPlayableStaticMetadata(
                    id: NSNumber(value: file.id.hashValue), assetURL: file.fileURL,
                    mediaType: file.fileURL.isVideo ? .video : .audio,
                    isLiveStream: false, title: file.title)])
                try await player.start(at: currentTime)
                try Task.checkCancellation()
                ready = true
            } catch {
                if !Task.isCancelled { self.error = error.localizedDescription }
            }
        }
        .onChange(of: currentTime) { _, value in
            guard ready, player.playerState != .stopped else { return }
            metrics?.currentTime = value
        }
        .onDisappear { player.optOut() }
    }
}
