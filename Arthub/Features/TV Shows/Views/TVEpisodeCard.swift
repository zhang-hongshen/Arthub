//
//  TVEpisodeCard.swift
//  Arthub
//
//  Created by 张鸿燊 on 28/2/2024.
//

import SwiftUI

/// Apple TV style episode card: 16:9 still with a progress bar, then
/// "EPISODE N", the title, a short overview and the runtime.
/// `.vertical` is used in shelves, `.horizontal` in episode lists.
struct TVEpisodeCard: View {
    
    var episode: TVEpisodeDetail
    var width: CGFloat
    var axis: Axis = .vertical
    /// Called when the card is clicked.
    var onPlay: () -> Void = {}
    
    @State private var isHovering = false
    
    var body: some View {
        let layout = axis == .vertical
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 20))
        layout {
            TVEpisodeStill()
            TVEpisodeInfo()
        }
        .frame(width: axis == .vertical ? width : nil, alignment: .leading)
        .contentShape(Rectangle())
        .opacity(episode.isAvailable ? 1 : 0.6)
        .onHover { isHovering = $0 }
        .onTapGesture(perform: onPlay)
        // One button for VoiceOver and agents, read as its episode number, title and overview.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onPlay() }
        .contextMenu { TVEpisodeContextMenu() }
        .task{ await fetchData() }
    }
    
}

extension TVEpisodeCard {
    
    @ViewBuilder
    func TVEpisodeStill() -> some View {
        ArtworkImage(url: episode.metadata.stillPath, aspectRatio: MediaDetail.stillAspectRatio)
            .frame(width: width, height: width / MediaDetail.stillAspectRatio)
            .clipped()
            .overlay { TVEpisodeStillOverlay() }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .scaleEffect(isHovering && episode.isAvailable ? 1.03 : 1)
            .animation(.easeOut(duration: 0.2), value: isHovering)
    }
    
    @ViewBuilder
    func TVEpisodeStillOverlay() -> some View {
        ZStack(alignment: .bottom) {
            if isHovering && episode.isAvailable {
                Color.black.opacity(0.25)
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxHeight: .infinity)
            }
            if !episode.isAvailable {
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(maxHeight: .infinity)
            }
            if episode.progress > 0 {
                ProgressView(value: min(episode.progress, 1))
                    .progressViewStyle(.linear)
                    .tint(.white)
                    .padding(10)
            }
        }
    }
    
    @ViewBuilder
    func TVEpisodeInfo() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Episode \(episode.metadata.episodeNumber)")
                .font(.caption.bold())
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            
            Text(verbatim: episode.metadata.name)
                .font(.headline)
                .lineLimit(1)
            
            if let overview = episode.metadata.overview, !overview.isEmpty {
                Text(verbatim: overview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(axis == .vertical ? 3 : 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            HStack(spacing: 6) {
                if episode.duration > 0 {
                    Text(verbatim: MediaDetail.runtime(episode.duration))
                }
                if let airDate = episode.metadata.airDate {
                    Text(verbatim: "·")
                    Text(airDate.formatted(date: .abbreviated, time: .omitted))
                }
                if !episode.isAvailable {
                    Text(verbatim: "·")
                    Text("Unavailable")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.leading)
    }
    
    @ViewBuilder
    func TVEpisodeContextMenu() -> some View {
        ShareLink(item: episode.fileURL,
                  subject: Text(verbatim: episode.metadata.name),
                  message: Text(verbatim: episode.metadata.overview ?? "" )) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
    }
}

extension TVEpisodeCard {
    
    func fetchData() async {
        do { try await episode.fetchDetail() }
        catch {}
    }
}
