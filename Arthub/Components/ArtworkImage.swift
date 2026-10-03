//
//  ArtworkImage.swift
//  Arthub
//
//  Created by 张鸿燊 on 1/3/2024.
//

import SwiftUI

/// Shows artwork read from disk: Infuse-style image files next to the media,
/// embedded cover data, or a TMDb image that `ArtworkStore` downloaded once.
struct ArtworkImage<Placeholder: View>: View {

    private var url: URL? = nil
    private var data: Data? = nil
    private var aspectRatio: CGFloat? = nil
    private var contentMode: SwiftUI.ContentMode = .fill
    private var placeholder: () -> Placeholder
    @State private var image: PlatformImage?

    init(url: URL?, aspectRatio: CGFloat? = nil, contentMode: SwiftUI.ContentMode = .fill,
         @ViewBuilder placeholder: @escaping () -> Placeholder = { DefaultImageView() }) {
        self.url = url
        self.aspectRatio = aspectRatio
        self.contentMode = contentMode
        self.placeholder = placeholder
        self._image = State(initialValue: url.flatMap(ArtworkStore.shared.cachedImage(for:)))
    }

    init(data: Data?, aspectRatio: CGFloat? = nil, contentMode: SwiftUI.ContentMode = .fill,
         @ViewBuilder placeholder: @escaping () -> Placeholder = { DefaultImageView() }) {
        self.data = data
        self.aspectRatio = aspectRatio
        self.contentMode = contentMode
        self.placeholder = placeholder
    }

    var body: some View {
        if let data {
            if let image = Image(data: data) {
                image.resizable()
                    .allowedDynamicRange(.high)
                    .interpolation(.high)
                    .aspectRatio(aspectRatio, contentMode: contentMode)
            } else {
                placeholder()
            }
        } else {
            Group {
                if let image {
                    Image(platformImage: image).resizable()
                } else {
                    placeholder()
                }
            }
            .aspectRatio(aspectRatio, contentMode: contentMode)
            .task(id: url) {
                guard let url else { image = nil; return }
                image = ArtworkStore.shared.cachedImage(for: url)
                if image == nil { image = await ArtworkStore.shared.image(for: url) }
            }
        }
    }
}

/// Keeps every image on disk. File URLs are read in place; TMDb URLs are
/// downloaded once into Application Support/Arthub/Artwork, named after their
/// TMDb size and file name (e.g. `w500/kqjL17yufvn9OVLyXYpvtyrFfak.jpg`), and
/// read from there afterwards.
final class ArtworkStore: @unchecked Sendable {

    static let shared = ArtworkStore()

    private let memory = NSCache<NSURL, PlatformImage>()
    private let directory = URL.applicationSupportDirectory
        .appending(path: "Arthub/Artwork", directoryHint: .isDirectory)

    func cachedImage(for url: URL) -> PlatformImage? {
        memory.object(forKey: url as NSURL)
    }

    func image(for url: URL) async -> PlatformImage? {
        if let cached = cachedImage(for: url) { return cached }
        guard let file = try? await localURL(for: url) else { return nil }
        let image = await Task.detached(priority: .userInitiated) {
            PlatformImage(contentsOfFile: file.path)
        }.value
        if let image { memory.setObject(image, forKey: url as NSURL) }
        return image
    }

    func localURL(for url: URL) async throws -> URL {
        guard !url.isFileURL else { return url }
        let file = directory.appending(path: url.pathComponents.suffix(2).joined(separator: "/"))
        let manager = FileManager.default
        if manager.fileExists(atPath: file.path) { return file }
        let (download, response) = try await URLSession.shared.download(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        try manager.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        do {
            try manager.moveItem(at: download, to: file)
        } catch where manager.fileExists(atPath: file.path) {
            // Another view downloaded the same image first.
        }
        return file
    }
}

private extension Image {
    init(platformImage: PlatformImage) {
        #if canImport(UIKit)
        self.init(uiImage: platformImage)
        #elseif canImport(AppKit)
        self.init(nsImage: platformImage)
        #endif
    }
}
