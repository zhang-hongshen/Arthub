//
//  MusicDetail.swift
//  Arthub
//
//  Created by 张鸿燊 on 1/2/2024.
//

import Foundation
import AVFoundation
import MediaPlayer

@Observable
class Song: MediaItem,Identifiable, Hashable {
    let id = UUID()
    let createdAt: Date = Date.now
    var modifiedAt: Date = Date.now
    
    var title: String
    var artist: Artist
    var composer: String
    var lyricist: String
    var arranger: String
    var releaseDate: Date?
    
    var lyrics: LyricsDetail
    var album: Album
    var discNumber: Int?
    var trackNumber: Int?

    /// Details edited in the inspector and not yet written into the file.
    var unsavedTags: Set<PartialKeyPath<Song>> = []
    var isSaving = false

    init(title: String = "" , fileURL: URL, duration: TimeInterval,
         artist: Artist = Artist(), composer: String = "", lyricist: String = "",
         arranger: String = "", releaseDate: Date? = nil, lyrics: LyricsDetail = LyricsDetail(),
         album: Album = Album(), trackNumber: Int? = nil, discNumber: Int? = nil) {
        self.title = title
        self.artist = artist
        self.composer = composer
        self.lyricist = lyricist
        self.arranger = arranger
        self.releaseDate = releaseDate
        self.lyrics =  lyrics
        self.album = album
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        super.init(fileURL: fileURL, duration: duration)
    }
    
    static func == (lhs: Song, rhs: Song) -> Bool {
        return lhs.title == rhs.title
        && lhs.artist == rhs.artist
        && lhs.album == rhs.album
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(artist)
        hasher.combine(album)
    }
}

extension Song {

    /// What the player and the system's Now Playing panel show for this song.
    var playlistItem: PlaylistItem {
        PlaylistItem(id: id.hashValue, url: fileURL, title: title, artist: artist.name,
                     albumTitle: album.title, albumArtist: album.artist.name,
                     artwork: album.cover.flatMap { MPMediaItemArtwork(data: $0) })
    }
    
    /// Reads the tags embedded in the file. Values already set stay.
    func loadMetadata() async throws {
        if let flac = AudioTags.readFLAC(fileURL) { flacMetadata(flac.comments, cover: flac.cover) }
        let asset = AVURLAsset(url: fileURL)
        let id3 = try await asset.loadMetadata(for: .id3Metadata)
        let iTunes = try await asset.loadMetadata(for: .iTunesMetadata)
        let common = try await asset.load(.commonMetadata)
        let tags = id3 + iTunes + common

        if title.isEmpty { title = await tags.string(.commonIdentifierTitle) ?? "" }
        if artist.name.isEmpty {
            artist.name = await tags.string(.id3MetadataLeadPerformer, .iTunesMetadataPerformer, .commonIdentifierArtist) ?? ""
        }
        if album.title.isEmpty {
            album.title = await tags.string(.id3MetadataAlbumTitle, .iTunesMetadataAlbum, .commonIdentifierAlbumName) ?? ""
        }
        // TPE2 is what taggers use for the album artist.
        if album.artist.name.isEmpty {
            album.artist.name = await tags.string(.id3MetadataBand, .iTunesMetadataAlbumArtist) ?? ""
        }
        if composer.isEmpty { composer = await tags.string(.id3MetadataComposer, .iTunesMetadataComposer) ?? "" }
        if lyricist.isEmpty { lyricist = await tags.string(.id3MetadataLyricist) ?? "" }
        if arranger.isEmpty { arranger = await tags.string(.iTunesMetadataArranger) ?? "" }
        if trackNumber == nil { trackNumber = await tags.number(.id3MetadataTrackNumber, .iTunesMetadataTrackNumber) }
        if discNumber == nil { discNumber = await tags.number(.id3MetadataPartOfASet, .iTunesMetadataDiscNumber) }
        // TDRL, then the recording time ID3v2.4 writes (TDRC) and the year ID3v2.3 writes (TYER).
        if releaseDate == nil {
            releaseDate = await tags.date(.id3MetadataReleaseTime, .id3MetadataRecordingTime, .id3MetadataYear,
                                          .iTunesMetadataReleaseDate)
        }
        // The first picture is the front cover.
        if album.cover == nil { album.cover = await tags.data(.iTunesMetadataCoverArt, .commonIdentifierArtwork) }
        if lyrics.body.isEmpty, let sylt = await tags.data(.id3MetadataSynchronizedLyric) {
            lyrics.body = SidecarParser.lyrics(sylt: sylt)
        }
        if lyrics.body.isEmpty, let text = await tags.string(.id3MetadataUnsynchronizedLyric, .iTunesMetadataLyrics) {
            lyrics.body = SidecarParser.lyrics(text: text)
        }
    }

    /// The song's lyrics file, or a new one named after the audio file next to it.
    func lyricsURL(format: String) -> URL {
        lyrics.fileURL ?? fileURL.deletingPathExtension().appendingPathExtension(format)
    }

    /// Writes the lyrics into the audio file, and into its lyrics file as well since that one is shown
    /// first. A file whose tags can't be written gets a new `.lrc` next to it instead.
    @MainActor
    func saveLyrics() async throws {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await AudioTags.write([.lyrics(Lyric.tagText(lyrics.body))], to: fileURL)
            if let url = lyrics.fileURL { try Lyric.write(lyrics.body, to: url) }
        } catch AudioTagError.unsupportedFormat, AudioTagError.unsupportedTag {
            let url = lyricsURL(format: "lrc")
            try Lyric.write(lyrics.body, to: url)
            lyrics.fileURL = url
        }
        lyrics.isUnsaved = false
    }

    /// Changes a detail in the inspector, to be written into the file on save. Album details change
    /// for this song alone, so it stops sharing its album with the other tracks.
    func edit<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<Song, Value>, to value: Value) {
        // `@Observable` notifies on every assignment, even an unchanged one.
        guard self[keyPath: keyPath] != value else { return }
        let albumDetails: [PartialKeyPath<Song>] = [\.album.title, \.album.artist.name, \.album.cover]
        if albumDetails.contains(keyPath), album.songs.count > 1 {
            let own = Album(title: album.title, artist: Artist(name: album.artist.name),
                            releaseDate: album.releaseDate, cover: album.cover)
            album.songs.removeAll { $0.id == id }
            own.songs = [self]
            album = own
        }
        self[keyPath: keyPath] = value
        unsavedTags.insert(keyPath)
    }

    /// Writes the details changed in the inspector into the audio file.
    @MainActor
    func saveMetadata() async throws {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        let saving = unsavedTags
        try await AudioTags.write(saving.compactMap(tag(for:)), to: fileURL)
        // Details first edited while saving stay unsaved.
        unsavedTags.subtract(saving)
    }

    private func tag(for keyPath: PartialKeyPath<Song>) -> AudioTag? {
        switch keyPath {
        case \Song.title: .title(title)
        case \Song.artist.name: .artist(artist.name)
        case \Song.album.title: .album(album.title)
        case \Song.album.artist.name: .albumArtist(album.artist.name)
        case \Song.composer: .composer(composer)
        case \Song.lyricist: .lyricist(lyricist)
        case \Song.arranger: .arranger(arranger)
        case \Song.trackNumber: .trackNumber(trackNumber)
        case \Song.discNumber: .discNumber(discNumber)
        case \Song.album.cover: .cover(album.cover)
        default: nil
        }
    }

    /// Looks the lyrics up online, word-by-word ones first, and saves what's found into the song,
    /// to be read from there next time.
    @MainActor
    func searchLyrics() async {
        guard lyrics.lookup != .searching else { return }
        lyrics.lookup = .searching
        do {
            // Without word timing on NetEase, LRCLIB's lines.
            var found = (try? await NetEase.lyrics(title: title, artist: artist.name, duration: duration)) ?? []
            if found.isEmpty {
                found = try await LRCLIB.lyrics(title: title, artist: artist.name, album: album.title, duration: duration)
            }
            // Lyrics added in the meantime, such as an imported file, stay.
            guard lyrics.body.isEmpty else {
                lyrics.lookup = nil
                return
            }
            lyrics.body = found
            lyrics.isUnsaved = !found.isEmpty
            lyrics.lookup = found.isEmpty ? .notFound : .found
            // Lyrics that can't be written stay shown, and can still be saved from the lyrics editor.
            if !found.isEmpty { try? await saveLyrics() }
        } catch {
            lyrics.lookup = .failed
        }
    }
}

extension Song {

    /// Vorbis comments, by their common names.
    private func flacMetadata(_ comments: [String: String], cover: Data?) {
        let text = { (names: [String]) in names.compactMap { comments[$0] }.first ?? "" }
        if title.isEmpty { title = text(["TITLE"]) }
        if artist.name.isEmpty { artist.name = text(["ARTIST"]) }
        if album.title.isEmpty { album.title = text(["ALBUM"]) }
        if album.artist.name.isEmpty { album.artist.name = text(["ALBUMARTIST", "ALBUM ARTIST"]) }
        if composer.isEmpty { composer = text(["COMPOSER"]) }
        if lyricist.isEmpty { lyricist = text(["LYRICIST"]) }
        if arranger.isEmpty { arranger = text(["ARRANGER"]) }
        if releaseDate == nil { releaseDate = AudioTags.date(in: text(["DATE", "YEAR"])) }
        if trackNumber == nil { trackNumber = AudioTags.number(in: text(["TRACKNUMBER"])) }
        if discNumber == nil { discNumber = AudioTags.number(in: text(["DISCNUMBER"])) }
        if album.cover == nil { album.cover = cover }
        if lyrics.body.isEmpty { lyrics.body = SidecarParser.lyrics(text: text(["LYRICS", "UNSYNCEDLYRICS"])) }
    }
}

/// The first value that loads among the tags with these identifiers, in the order given.
private extension [AVMetadataItem] {

    func string(_ identifiers: AVMetadataIdentifier...) async -> String? {
        for item in items(identifiers) {
            if let value = try? await item.load(.stringValue) { return value }
        }
        return nil
    }

    func data(_ identifiers: AVMetadataIdentifier...) async -> Data? {
        for item in items(identifiers) {
            if let value = try? await item.load(.dataValue) { return value }
        }
        return nil
    }

    func number(_ identifiers: AVMetadataIdentifier...) async -> Int? {
        for item in items(identifiers) {
            if let value = try? await item.loadNumber() { return value }
        }
        return nil
    }

    func date(_ identifiers: AVMetadataIdentifier...) async -> Date? {
        for item in items(identifiers) {
            if let value = try? await item.loadDate() { return value }
        }
        return nil
    }

    private func items(_ identifiers: [AVMetadataIdentifier]) -> [AVMetadataItem] {
        identifiers.flatMap { AVMetadataItem.metadataItems(from: self, filteredByIdentifier: $0) }
    }
}
