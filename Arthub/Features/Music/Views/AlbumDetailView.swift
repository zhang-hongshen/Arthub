//
//  AlbumDetailView.swift
//  Arthub
//
//  Created by 张鸿燊 on 17/3/2024.
//

import SwiftUI
import OrderedCollections

struct AlbumDetailView: View {

    var album: Album
    var onEditMetadata: ((Song) -> Void)? = nil

    @Environment(ArthubAudioPlayer.self) private var player
    @State private var hoveredSongID: Song.ID?
    @State private var selectedSongID: Song.ID?
    @State private var searchText = ""

    private var sortedSongs: [Song] {
        groupedAlbum.values.flatMap { $0 }
    }

    private var groupedAlbum: OrderedDictionary<Int, [Song]> {
        var res: OrderedDictionary<Int, [Song]> = [:]
        album.songs.forEach { song in
            res.updateValue(forKey: song.discNumber ?? 1, default: []) { $0.append(song) }
        }
        res.sort { $0.key < $1.key }
        return res.mapValues { $0.sorted { ($0.trackNumber ?? .max) < ($1.trackNumber ?? .max) } }
    }

    /// The track list narrowed by the search text; playback still uses the whole album.
    private var filteredAlbum: OrderedDictionary<Int, [Song]> {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return groupedAlbum }
        return groupedAlbum
            .mapValues { songs in
                songs.filter { $0.title.localizedCaseInsensitiveContains(query)
                    || $0.artist.name.localizedCaseInsensitiveContains(query) }
            }
            .filter { !$0.value.isEmpty }
    }

    private var totalMinutes: Int {
        Int((album.songs.reduce(0) { $0 + $1.duration } / 60).rounded())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Header()
                TrackList()
                Footer()
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 24)
        }
        .navigationTitle("")
        .searchable(text: $searchText, placement: .toolbar, prompt: Text("Find in Album"))
    }
}

// MARK: Header

extension AlbumDetailView {

    @ViewBuilder
    func Header() -> some View {
        HStack(alignment: .bottom, spacing: 32) {
            ArtworkImage(data: album.cover, aspectRatio: 1)
                .frame(width: 270, height: 270)
                .cornerRadius()
                .shadow()

            VStack(alignment: .leading, spacing: 4) {
                Spacer()
                Text(album.title)
                    .font(.largeTitle.bold())
                    .lineLimit(2)
                Text(album.artist.name)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(.tint)
                    .lineLimit(1)
                if let year = album.releaseDate?.formatted(.dateTime.year()) {
                    Text(year)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 12) {
                    Button {
                        play(shuffled: true)
                    } label: {
                        Image(systemName: "shuffle")
                            .font(.title3.bold())
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)

                    Button {
                        play(shuffled: false)
                    } label: {
                        Label("Play", systemImage: "play.fill")
                            .font(.title3.bold())
                            .frame(width: 100, height: 36)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                }
                .foregroundStyle(.tint)
                .disabled(!album.songs.contains(where: \.isAvailable))
            }
            .frame(height: 270)

            Spacer(minLength: 0)
        }
    }
}

// MARK: Track List

extension AlbumDetailView {

    @ViewBuilder
    func TrackList() -> some View {
        let showsDisc = groupedAlbum.count > 1
        let discs = filteredAlbum
        VStack(alignment: .leading, spacing: 0) {
            if discs.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            }
            ForEach(discs.elements, id: \.key) { discNumber, songs in
                if showsDisc {
                    Text("Disc \(discNumber)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.top, discNumber == discs.keys.first ? 0 : 24)
                        .padding(.bottom, 8)
                    Divider()
                }
                ForEach(songs) { song in
                    TrackRow(song)
                }
            }
        }
    }

    @ViewBuilder
    func TrackRow(_ song: Song) -> some View {
        let isCurrent = player.currentItemID == song.id.hashValue
        let isHovered = hoveredSongID == song.id
        let isSelected = selectedSongID == song.id
        let primary = isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(song.isAvailable ? .primary : .secondary)
        let secondary = isSelected ? AnyShapeStyle(.white.opacity(0.8)) : AnyShapeStyle(.secondary)
        let accent = isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.tint)

        HStack(alignment: .center, spacing: 16) {
            Group {
                if isHovered && song.isAvailable {
                    Button {
                        if isCurrent { player.togglePlayPause() } else { play(from: song) }
                    } label: {
                        Image(systemName: isCurrent && player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundStyle(accent)
                    }
                    .buttonStyle(.plain)
                } else if isCurrent {
                    Waveform(animated: player.isPlaying)
                        .frame(width: 18, height: 14)
                        .foregroundStyle(accent)
                } else {
                    Text(song.trackNumber?.formatted() ?? "")
                        .monospacedDigit()
                        .foregroundStyle(secondary)
                }
            }
            .frame(width: 24, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .foregroundStyle(primary)
                    .lineLimit(1)
                if song.artist.name != album.artist.name, !song.artist.name.isEmpty {
                    Text(song.artist.name)
                        .font(.subheadline)
                        .foregroundStyle(secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(song.duration.formatted())
                .monospacedDigit()
                .foregroundStyle(secondary)

            Menu {
                TrackMenuItems(song)
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(isHovered || isSelected ? accent : secondary)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.tertiary))
                .opacity(isSelected || isHovered ? 1 : 0)
        }
        .overlay(alignment: .bottom) {
            if !isSelected && !isHovered {
                Divider().padding(.leading, 52).padding(.trailing, 12)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                if hovering {
                    hoveredSongID = song.id
                } else if hoveredSongID == song.id {
                    hoveredSongID = nil
                }
            }
        }
        .gesture(
            TapGesture(count: 2).onEnded {
                selectedSongID = song.id
                play(from: song)
            }
            .exclusively(before: TapGesture().onEnded {
                selectedSongID = song.id
            })
        )
        .contextMenu { TrackMenuItems(song) }
    }

    @ViewBuilder
    func TrackMenuItems(_ song: Song) -> some View {
        Button("Play", systemImage: "play.fill") { play(from: song) }
            .disabled(!song.isAvailable)
        if let onEditMetadata {
            Button("Edit Metadata", systemImage: "info.circle") { onEditMetadata(song) }
        }
        ShareLink(item: song.fileURL, message: Text(verbatim: song.title)) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
    }
}

// MARK: Footer

extension AlbumDetailView {

    @ViewBuilder
    func Footer() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let releaseDate = album.releaseDate {
                Text(releaseDate.formatted(date: .long, time: .omitted))
            }
            Text("\(album.songs.count) songs, \(totalMinutes) minutes")
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
}

// MARK: Playback

extension AlbumDetailView {

    func play(shuffled: Bool) {
        let songs = sortedSongs.filter(\.isAvailable)
        guard !songs.isEmpty else { return }
        if player.shuffled != shuffled { player.toggleShuffle() }
        let start = shuffled ? songs.indices.randomElement()! : 0
        startPlay(songs, from: start)
    }

    func play(from song: Song) {
        let songs = sortedSongs.filter(\.isAvailable)
        guard let index = songs.firstIndex(where: { $0.id == song.id }) else { return }
        startPlay(songs, from: index)
    }

    private func startPlay(_ songs: [Song], from index: Int) {
        player.setPlaylist((songs[index...] + songs[..<index]).map(\.playlistItem))
        player.start()
    }
}
