import Foundation
import MCP
import TMDb
#if os(macOS)
import AppKit
#endif

/// A video an agent asked to play. `ContentView` shows it in a sheet.
struct AgentVideo: Identifiable {
    let id = UUID()
    let file: LibraryFile
    /// `nil` resumes the saved progress.
    let startTime: TimeInterval?
}

/// The MCP tools Arthub offers AI agents such as ModelCraft, and the playback they start.
///
/// Every library item has an id made of its kind and a key:
/// `song:<file id>`, `album:<file id of one of its tracks>`, `artist:<name>`, `movie:<TMDb id>`,
/// `show:<TMDb id>`, `episode:<file id>`, and `video:<file id>` for a video not matched to TMDb.
@MainActor @Observable
final class AgentTools {
    nonisolated static let serverName = "Arthub"

    nonisolated static let instructions = """
        These tools are the user's own media library and media player on this Mac: the movies, TV shows, and music \
        files they keep in folders on this Mac or on a home server (NAS). Use them whenever the user wants to watch, \
        listen to, or play something, asks what movies, shows, or music they have, asks where they left off in a show, \
        controls what is playing (pause, next song, skip ahead), or wants to add a media file to their collection. \
        The user does not need to name the app: "play some Jay Chou", "继续看权力的游戏", and "我有哪些电影" all mean these tools. \
        Find items with search_library first; every other tool takes the ids it returns.
        """

    let audioPlayer: ArthubAudioPlayer
    let videoPlayer: ArthubVideoPlayer
    let music: MusicViewModel
    /// The video playing at an agent's request.
    var video: AgentVideo?

    private var library: LibraryViewModel { LibraryViewModel.shared }

    init(audioPlayer: ArthubAudioPlayer, videoPlayer: ArthubVideoPlayer, music: MusicViewModel) {
        self.audioPlayer = audioPlayer
        self.videoPlayer = videoPlayer
        self.music = music
    }

    // MARK: - Tools

    nonisolated static let searchLibrary = Tool(
        name: "search_library",
        title: "Search the library",
        description: """
            Searches the user's own collection of movies, TV shows, and music (the files on their Mac and home server, \
            not a streaming catalog). Use it to answer what the user has ("do I have Inception?", "我有哪些周杰伦的歌") \
            and to get the id of anything before playing it or looking at its details. \
            Returns one line per match: its kind, title with year or artist, and its id, such as `movie:27205`. \
            Matching is by words, not meaning: an item matches when its title, original title, artist, album, show, or \
            episode name contains every word of the query, ignoring case and accents. Pass a name, not a sentence or a \
            genre. Movies and shows carry one translated title plus their original title, so when nothing is found, try \
            the name in the other language. \
            Leave the query empty with a kind to list everything of that kind, such as all movies.
            """,
        inputSchema: [
            "type": "object",
            "properties": [
                "query": [
                    "type": "string",
                    "description": "Names to look for, such as \"Inception\", \"周杰伦 晴天\", \"Doctor Who S02E03\". Empty lists everything of `kind`.",
                ],
                "kind": [
                    "type": "string",
                    "enum": ["song", "album", "artist", "movie", "show", "episode", "video"],
                    "description": "Only return this kind. \"show\" is a TV series; \"episode\" one episode of it; \"video\" a video file that could not be identified as a movie or episode. Leave out to search all kinds.",
                ],
                "limit": [
                    "type": "integer",
                    "minimum": 1,
                    "maximum": 100,
                    "default": 20,
                    "description": "How many items to return, at most 100.",
                ],
            ],
            "additionalProperties": false,
        ],
        annotations: .init(title: "Search the library", readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
    )

    nonisolated static let getItem = Tool(
        name: "get_item",
        title: "Get item details",
        description: """
            Looks up one item of the user's collection by the id search_library gave it. Use it to answer questions about \
            the item, such as what a movie is about, which songs are on an album, or how far the user has watched a show \
            ("我权力的游戏看到哪了"). Returns: for a song, its tags and file; for an album, its tracks in order; for an artist, \
            their albums; for a movie, its year, runtime, genres, overview, and how far the user watched; for a show, every \
            episode in the collection with its watch progress and the episode up next; for an episode, its overview and \
            progress. Related items come with their ids.
            """,
        inputSchema: [
            "type": "object",
            "properties": [
                "id": ["type": "string", "description": "An id from search_library, such as \"movie:27205\"."],
            ],
            "required": ["id"],
            "additionalProperties": false,
        ],
        annotations: .init(title: "Get item details", readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
    )

    nonisolated static let play = Tool(
        name: "play",
        title: "Play",
        description: """
            Starts playing an item of the user's collection on this Mac. Use it whenever the user asks to play, watch, \
            listen to, or continue something ("放首晴天", "继续看权力的游戏", "play the Inception movie"). \
            By id kind: a song plays, then the rest of its album; an album plays its tracks in order; an artist plays \
            all their songs; a movie, episode, or video opens in the app's window, brought to the front, and resumes where \
            the user stopped (the window must be open); a show \
            plays the episode up next (the one being watched, or the next after a finished one). \
            Starting music stops any video and starting a video stops the music. Returns what started playing.
            """,
        inputSchema: [
            "type": "object",
            "properties": [
                "id": ["type": "string", "description": "An id from search_library, such as \"album:…\" or \"show:1399\"."],
                "start_at": [
                    "type": "number",
                    "minimum": 0,
                    "description": "Seconds from the beginning to start at. Pass 0 to watch a video from the start; leave out to resume.",
                ],
                "shuffle": [
                    "type": "boolean",
                    "description": "Music only: true plays in random order, false in order. Leave out to keep the current setting.",
                ],
            ],
            "required": ["id"],
            "additionalProperties": false,
        ],
        annotations: .init(title: "Play", readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false)
    )

    nonisolated static let playbackControl = Tool(
        name: "playback_control",
        title: "Control playback",
        description: """
            Controls the music or video already playing on this Mac. Use it for requests like "暂停", "继续放", "下一首", \
            "上一首", "快进30秒", "跳到第10分钟", or "stop". Acts on the video when one is open, otherwise on the music. \
            Actions: pause; resume; next and previous move through the music queue (previous restarts the current song \
            unless it is in its first 3 seconds; a video is a queue of one, so next ends it — to watch another episode, \
            use play); stop ends playback and closes the video; seek jumps to `value` seconds \
            from the start; skip moves by `value` seconds, back when negative. Returns what is playing afterwards. \
            To play something else, use play instead.
            """,
        inputSchema: [
            "type": "object",
            "properties": [
                "action": [
                    "type": "string",
                    "enum": ["pause", "resume", "next", "previous", "stop", "seek", "skip"],
                ],
                "value": ["type": "number", "description": "Seconds, for seek and skip."],
            ],
            "required": ["action"],
            "additionalProperties": false,
        ],
        annotations: .init(title: "Control playback", readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false)
    )

    nonisolated static let nowPlaying = Tool(
        name: "now_playing",
        title: "Now playing",
        description: """
            Tells what is playing on this Mac right now. Use it for "这是什么歌", "what's playing?", or "下一首是什么", and \
            before acting on "this song" or "this episode". Returns, for the music and the video separately: the title \
            with artist and album, playing or paused, the position and length, its place in the queue, and for music the \
            repeat and shuffle settings and the next song (unknown while shuffling). Says "Nothing is playing." when nothing is.
            """,
        inputSchema: ["type": "object", "properties": [:], "additionalProperties": false],
        annotations: .init(title: "Now playing", readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
    )

    nonisolated static let listLibraries = Tool(
        name: "list_libraries",
        title: "List library folders",
        description: """
            Lists the folders that make up the user's media collection, on this Mac or on a home server (NAS). \
            Returns each folder's name, its path or server address, whether it can be reached right now, and how many \
            videos and songs it holds. Use it when the user asks where their media is kept or why something is \
            missing, and before import_file, to offer the user these folders when they did not say where a file goes.
            """,
        inputSchema: ["type": "object", "properties": [:], "additionalProperties": false],
        annotations: .init(title: "List library folders", readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
    )

    nonisolated static let importFile = Tool(
        name: "import_file",
        title: "Add a file to the library",
        description: """
            Adds a movie, episode, song, subtitle, or lyrics file on this Mac to the user's media collection, by copying \
            or moving it into one of its folders (which may be on a home server). Use it when the user hands over a file \
            and asks to add, save, upload, or put it in their library ("把这个电影放进我的片库"). \
            When they did not say which folder, call list_libraries and ask them; do not guess. \
            An existing file is never replaced. The collection is rescanned afterwards, so the file appears there \
            shortly. Media is identified by its folders and file name, so choose a subfolder and keep or fix \
            the file name following these patterns:
            Movies: `Inception (2010)/Inception (2010).mkv`
            TV shows: `Doctor Who (2005)/Season 01/Doctor Who (2005) S01E01.mkv`
            Music: `Artist/Album (2019)/01 Title.flac` (embedded tags come first)
            Subtitles and lyrics go next to their video or song with the same name, such as `Inception (2010).zh-Hans.srt`.
            """,
        inputSchema: [
            "type": "object",
            "properties": [
                "source_path": ["type": "string", "description": "The full path of the file on this Mac."],
                "library": ["type": "string", "description": "The library folder's name, as list_libraries gives it."],
                "subfolder": [
                    "type": "string",
                    "description": "Folders inside the library to put the file in, separated by \"/\", such as \"Inception (2010)\". Created when missing.",
                ],
                "mode": [
                    "type": "string",
                    "enum": ["copy", "move"],
                    "default": "copy",
                    "description": "copy keeps the original file; move removes it from where it was.",
                ],
            ],
            "required": ["source_path", "library"],
            "additionalProperties": false,
        ],
        annotations: .init(title: "Add a file to the library", readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false)
    )

    nonisolated static let all = [searchLibrary, getItem, play, playbackControl, nowPlaying, listLibraries, importFile]

    /// Runs one tool call. Mistakes come back as a tool error the model can read and fix.
    func call(_ params: CallTool.Parameters) async -> CallTool.Result {
        let arguments = params.arguments ?? [:]
        do {
            let text: String
            switch params.name {
            case Self.searchLibrary.name:
                text = search(arguments["query"]?.stringValue ?? "", kind: arguments["kind"]?.stringValue,
                              limit: min(max(arguments["limit"]?.intValue ?? 20, 1), 100))
            case Self.getItem.name:
                text = try details(of: try id(in: arguments))
            case Self.play.name:
                text = try play(try id(in: arguments), startAt: seconds(arguments["start_at"]),
                                shuffle: arguments["shuffle"]?.boolValue)
            case Self.playbackControl.name:
                text = try control(arguments["action"]?.stringValue ?? "", value: seconds(arguments["value"]))
            case Self.nowPlaying.name:
                text = nowPlayingText()
            case Self.listLibraries.name:
                text = librariesText()
            case Self.importFile.name:
                text = try await importFile(arguments)
            default:
                throw AgentToolError("Unknown tool \(params.name). Arthub's tools are: \(Self.all.map(\.name).joined(separator: ", ")).")
            }
            return CallTool.Result(content: [.text(text: text, annotations: nil, _meta: nil)])
        } catch {
            return CallTool.Result(content: [.text(text: error.localizedDescription, annotations: nil, _meta: nil)], isError: true)
        }
    }

    private func id(in arguments: [String: Value]) throws -> String {
        guard let id = arguments["id"]?.stringValue, !id.isEmpty else {
            throw AgentToolError("Pass the item's id in \"id\". search_library gives each item's id.")
        }
        return id
    }

    /// JSON numbers may arrive as integers or doubles.
    private func seconds(_ value: Value?) -> TimeInterval? {
        value?.doubleValue ?? value?.intValue.map(TimeInterval.init)
    }

    // MARK: - search_library

    private struct Entry {
        let id: String
        let kind: String
        let line: String
        /// The words a query is matched against.
        let text: String
    }

    private func search(_ query: String, kind: String?, limit: Int) -> String {
        let words = query.split(whereSeparator: \.isWhitespace).map(String.init)
        let matches = entries().filter { entry in
            (kind == nil || entry.kind == kind) && words.allSatisfy { entry.text.localizedStandardContains($0) }
        }
        guard !matches.isEmpty else {
            if library.files.isEmpty && library.isScanning {
                return "Arthub is still loading the library. Try again in a moment."
            }
            return query.isEmpty
                ? "The library has no \(kind ?? "item")s."
                : "Nothing in the library matches \"\(query)\". Try fewer words, other words, or the other language."
        }
        var lines = ["\(matches.count) found\(matches.count > limit ? ", showing the first \(limit)" : ""):"]
        lines += matches.prefix(limit).map { "- [\($0.kind)] \($0.line) — id: \($0.id)" }
        return lines.joined(separator: "\n")
    }

    private func entries() -> [Entry] {
        var result: [Entry] = []
        var albums: Set<String> = []
        var artists: Set<String> = []
        var movies: Set<Int> = []
        var shows: Set<Int> = []
        for file in library.files {
            let offline = file.isAvailable ? "" : " (offline)"
            if !file.fileURL.isVideo {
                let title = file.audio?.title ?? file.fileURL.fileName
                let artist = file.audio?.artist ?? ""
                let album = file.audio?.album ?? ""
                result.append(Entry(id: "song:\(file.id)", kind: "song",
                                    line: [title, artist, album].filter { !$0.isEmpty }.joined(separator: " — ") + offline,
                                    text: "\(title) \(artist) \(album)"))
                if !album.isEmpty, albums.insert(albumKey(of: file)).inserted {
                    let byArtist = albumArtist(of: file)
                    result.append(Entry(id: "album:\(file.id)", kind: "album",
                                        line: byArtist.isEmpty ? album : "\(album) — \(byArtist)",
                                        text: "\(album) \(byArtist)"))
                }
                if !artist.isEmpty, artists.insert(artist).inserted {
                    result.append(Entry(id: "artist:\(artist)", kind: "artist", line: artist, text: artist))
                }
            } else if let movie = file.movie {
                guard movies.insert(movie.id).inserted else { continue }
                result.append(Entry(id: "movie:\(movie.id)", kind: "movie", line: titleWithYear(movie.title, movie.releaseDate) + offline,
                                    text: "\(movie.title) \(movie.originalTitle ?? "")"))
            } else if let series = file.series, let episode = file.episode {
                if shows.insert(series.id).inserted {
                    result.append(Entry(id: "show:\(series.id)", kind: "show", line: titleWithYear(series.name, series.firstAirDate),
                                        text: "\(series.name) \(series.originalName ?? "")"))
                }
                let number = episodeNumber(episode)
                result.append(Entry(id: "episode:\(file.id)", kind: "episode",
                                    line: "\(series.name) \(number) · \(episode.name)" + offline,
                                    text: "\(series.name) \(number) \(episode.name)"))
            } else {
                result.append(Entry(id: "video:\(file.id)", kind: "video", line: file.fileURL.lastPathComponent + offline,
                                    text: file.fileURL.lastPathComponent))
            }
        }
        return result
    }

    // MARK: - get_item

    private func details(of id: String) throws -> String {
        let (kind, key) = try parse(id)
        var lines: [String] = []
        switch kind {
        case "song":
            let file = try libraryFile(key)
            let audio = file.audio
            lines.append("Song: \(audio?.title ?? file.fileURL.fileName)")
            lines.append(field("Artist", audio?.artist))
            lines.append(field("Album", audio?.album))
            if let audio, !audio.album.isEmpty { lines.append("Album id: album:\(file.id)") }
            lines.append(field("Album artist", audio?.albumArtist))
            lines.append(field("Composer", audio?.composer))
            lines.append(field("Lyricist", audio?.lyricist))
            lines.append(field("Track", audio?.trackNumber.map { "\($0), disc \(audio?.discNumber ?? 1)" }))
            lines.append(field("Year", audio?.releaseDate.map { String(Calendar.current.component(.year, from: $0)) }))
            lines.append("Length: \(file.duration.formatted())")
            lines.append("Embedded lyrics: \(audio?.lyrics.isEmpty == false ? "yes" : "no")")
            lines += fileLines(file)
        case "album":
            let tracks = try albumTracks(of: libraryFile(key))
            let first = tracks[0]
            lines.append("Album: \(first.audio?.album ?? "")")
            lines.append(field("Artist", albumArtist(of: first)))
            lines.append(field("Year", first.audio?.releaseDate.map { String(Calendar.current.component(.year, from: $0)) }))
            lines.append("Tracks:")
            lines += tracks.map { track in
                let number = track.audio?.trackNumber.map { "\(track.audio?.discNumber ?? 1)-\(String(format: "%02d", $0)) " } ?? ""
                return "- \(number)\(track.audio?.title ?? track.fileURL.fileName) (\(track.duration.formatted())) — id: song:\(track.id)"
            }
        case "artist":
            let songs = artistSongs(key)
            guard !songs.isEmpty else { throw AgentToolError("No songs by \"\(key)\" are in the library.") }
            lines.append("Artist: \(key)")
            lines.append("Songs: \(songs.count). Play artist:\(key) to play them all.")
            lines.append("Albums:")
            var seen: Set<String> = []
            for song in songs where seen.insert(albumKey(of: song)).inserted {
                let count = songs.filter { albumKey(of: $0) == albumKey(of: song) }.count
                let album = song.audio?.album ?? ""
                lines.append("- \(album.isEmpty ? "No album" : album) (\(count) songs) — id: album:\(song.id)")
            }
        case "movie":
            let files = movieFiles(key)
            guard let movie = files.first?.movie else { throw AgentToolError("No movie with the id \(id) is in the library.") }
            lines.append("Movie: \(titleWithYear(movie.title, movie.releaseDate))")
            if movie.originalTitle != movie.title { lines.append(field("Original title", movie.originalTitle)) }
            lines.append(field("Tagline", movie.tagline))
            lines.append(field("Runtime", movie.runtime.map { "\($0) min" }))
            lines.append(field("Genres", movie.genres?.map(\.name).joined(separator: ", ")))
            lines.append(field("Overview", movie.overview))
            lines.append("Progress: \(progress(WatchProgressStore.shared.metrics(.movie, tmdbID: movie.id), duration: files[0].duration))")
            for file in files { lines += fileLines(file) }
        case "show":
            let episodes = showEpisodes(key)
            guard let series = episodes.first?.series else { throw AgentToolError("No show with the id \(id) is in the library.") }
            lines.append("Show: \(titleWithYear(series.name, series.firstAirDate))")
            lines.append(field("Genres", series.genres?.map(\.name).joined(separator: ", ")))
            lines.append(field("Overview", series.overview))
            if let next = upNext(episodes), let episode = next.episode {
                lines.append("Up next: \(episodeNumber(episode)) \(episode.name) — id: episode:\(next.id)")
            }
            lines.append("Episodes in the library:")
            lines += episodes.compactMap { file in
                guard let episode = file.episode else { return nil }
                let metrics = WatchProgressStore.shared.metrics(.episode, tmdbID: episode.id)
                let offline = file.isAvailable ? "" : " (offline)"
                return "- \(episodeNumber(episode)) \(episode.name) — \(progress(metrics, duration: file.duration))\(offline) — id: episode:\(file.id)"
            }
        case "episode":
            let file = try libraryFile(key)
            guard let series = file.series, let episode = file.episode else {
                throw AgentToolError("\(id) is not an episode. Use the id search_library gave it.")
            }
            lines.append("Episode: \(series.name) \(episodeNumber(episode)) · \(episode.name)")
            lines.append("Show id: show:\(series.id)")
            lines.append(field("Aired", episode.airDate?.formatted(date: .long, time: .omitted)))
            lines.append(field("Overview", episode.overview))
            lines.append("Progress: \(progress(WatchProgressStore.shared.metrics(.episode, tmdbID: episode.id), duration: file.duration))")
            lines += fileLines(file)
        case "video":
            let file = try libraryFile(key)
            lines.append("Video: \(file.fileURL.lastPathComponent) (not matched to a movie or episode)")
            lines += fileLines(file)
        default:
            throw unknownKind(id)
        }
        return lines.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    // MARK: - play

    private func play(_ id: String, startAt: TimeInterval?, shuffle: Bool?) throws -> String {
        let (kind, key) = try parse(id)
        switch kind {
        case "song":
            let song = try libraryFile(key)
            let tracks = song.audio?.album.isEmpty == false ? albumTracks(of: song) : [song]
            return try playMusic(tracks, from: song, startAt: startAt, shuffle: shuffle)
        case "album":
            return try playMusic(albumTracks(of: libraryFile(key)), from: nil, startAt: startAt, shuffle: shuffle)
        case "artist":
            let songs = artistSongs(key)
            guard !songs.isEmpty else { throw AgentToolError("No songs by \"\(key)\" are in the library.") }
            return try playMusic(songs, from: nil, startAt: startAt, shuffle: shuffle)
        case "movie":
            let files = movieFiles(key)
            guard !files.isEmpty else { throw AgentToolError("No movie with the id \(id) is in the library.") }
            return try playVideo(files.first(where: \.isAvailable) ?? files[0], startAt: startAt)
        case "show":
            guard let next = upNext(showEpisodes(key)) else { throw AgentToolError("No show with the id \(id) is in the library.") }
            return try playVideo(next, startAt: startAt)
        case "episode", "video":
            return try playVideo(try libraryFile(key), startAt: startAt)
        default:
            throw unknownKind(id)
        }
    }

    /// Plays the songs from `first`, or from the start, followed by the ones before it.
    private func playMusic(_ files: [LibraryFile], from first: LibraryFile?, startAt: TimeInterval?, shuffle: Bool?) throws -> String {
        let available = files.filter(\.isAvailable)
        guard !available.isEmpty else { throw AgentToolError("These songs are offline: their library folder cannot be reached.") }
        let found = available.compactMap { file in music.song(forFileID: file.id).map { (file.id, $0) } }
        guard !found.isEmpty else { throw AgentToolError("Arthub is still loading its music. Try again in a moment.") }
        let songs = found.map(\.1)
        if let shuffle { audioPlayer.shuffled = shuffle }
        var index = first.flatMap { first in found.firstIndex { $0.0 == first.id } } ?? 0
        if first == nil && audioPlayer.shuffled { index = songs.indices.randomElement() ?? 0 }
        video = nil
        videoPlayer.stop()
        let queue = Array(songs[index...] + songs[..<index])
        audioPlayer.setPlaylist(queue.map(\.playlistItem))
        audioPlayer.start(at: startAt ?? 0)
        music.selectedSongID = queue[0].id
        let song = queue[0]
        let artist = song.artist.name.isEmpty ? "" : " by \(song.artist.name)"
        return "Playing \(song.title)\(artist)" + (queue.count > 1 ? ", then \(queue.count - 1) more songs." : ".")
    }

    private func playVideo(_ file: LibraryFile, startAt: TimeInterval?) throws -> String {
        guard file.isAvailable else { throw AgentToolError("\(file.title) is offline: its library folder cannot be reached.") }
        #if os(macOS)
        // The video shows in a sheet on the main window.
        guard NSApp.windows.contains(where: { $0.isVisible && $0.canBecomeMain }) else {
            throw AgentToolError("Arthub has no open window to play the video in. Ask the user to open Arthub's window, then try again.")
        }
        NSApp.activate()
        #endif
        audioPlayer.stop()
        video = AgentVideo(file: file, startTime: startAt)
        if let series = file.series, let episode = file.episode {
            return "Playing \(series.name) \(episodeNumber(episode)) · \(episode.name) in Arthub's window."
        }
        return "Playing \(file.title) in Arthub's window."
    }

    // MARK: - playback_control and now_playing

    private func control(_ action: String, value: TimeInterval?) throws -> String {
        let isVideo = videoPlayer.playerState != .stopped
        let player: ArthubPlayer = isVideo ? videoPlayer : audioPlayer
        guard player.playerState != .stopped else { throw AgentToolError("Nothing is playing. Use play to start something.") }
        switch action {
        case "pause": player.pause()
        case "resume": player.play()
        case "next": player.nextTrack()
        case "previous": player.previousTrack()
        case "stop":
            player.stop()
            if isVideo { video = nil }
        case "seek", "skip":
            guard let value else { throw AgentToolError("Pass the seconds in \"value\" for \(action).") }
            if action == "seek" { player.seek(to: value) } else { player.skip(by: value) }
        default:
            throw AgentToolError("Unknown action \"\(action)\". Use pause, resume, next, previous, stop, seek, or skip.")
        }
        return nowPlayingText()
    }

    private func nowPlayingText() -> String {
        var lines: [String] = []
        let players: [(String, ArthubPlayer)] = [("Video", videoPlayer), ("Music", audioPlayer)]
        for (name, player) in players {
            guard player.playerState != .stopped, let index = player.currentIndex else { continue }
            let item = player.items[index]
            let by = [item.artist, item.albumTitle].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
            let state = player.isPlaying ? "playing" : "paused"
            lines.append("\(name), \(state): \(item.title)\(by.isEmpty ? "" : " — \(by)")")
            lines.append("Position: \(player.currentTime.formatted()) of \(player.duration.formatted())")
            if player.items.count > 1 { lines.append("Queue: item \(index + 1) of \(player.items.count)") }
            if player === audioPlayer {
                let repeatMode = switch player.playerMode {
                case .noRepeat: "off"
                case .repeatPlaylist: "all"
                case .repeatItem: "one"
                }
                lines.append("Repeat: \(repeatMode), shuffle: \(audioPlayer.shuffled ? "on" : "off")")
                // The next shuffled song is only picked when it starts.
                if !audioPlayer.shuffled, let next = player.nextIndex() { lines.append("Up next: \(player.items[next].title)") }
            }
        }
        return lines.isEmpty ? "Nothing is playing." : lines.joined(separator: "\n")
    }

    // MARK: - list_libraries and import_file

    private var libraries: [String] {
        UserDefaults.standard.value(forKey: UserDefaults.library, default: [])
    }

    private func librariesText() -> String {
        guard !libraries.isEmpty else {
            return "The library has no folders. The user adds them in Arthub's Settings, under Library."
        }
        return libraries.map { key in
            let remote = RemoteFolder.isRemote(key)
            let files = library.files.filter { $0.library == key }
            let videos = files.filter(\.fileURL.isVideo).count
            let location = remote ? "network server \(key)" : (library.folderURL(for: key)?.path ?? key)
            let state = library.offlineLibraries.contains(key) ? "unreachable" : "reachable"
            return "- \(library.displayName(for: key)) — \(location), \(state) — \(videos) videos, \(files.count - videos) songs"
        }.joined(separator: "\n")
    }

    private func importFile(_ arguments: [String: Value]) async throws -> String {
        guard let path = arguments["source_path"]?.stringValue, !path.isEmpty else {
            throw AgentToolError("Pass the file's full path in \"source_path\".")
        }
        let source = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: source.path, isDirectory: &isDirectory) else {
            throw AgentToolError("There is no file at \(source.path).")
        }
        guard !isDirectory.boolValue else { throw AgentToolError("\(source.path) is a folder. Add its files one by one.") }

        let name = arguments["library"]?.stringValue ?? ""
        guard let key = libraries.first(where: { $0 == name || library.displayName(for: $0) == name }) else {
            throw AgentToolError("No library folder is named \"\(name)\". The folders are:\n\(librariesText())")
        }
        let components = (arguments["subfolder"]?.stringValue ?? "").split(separator: "/").map(String.init)
        // The file must land inside the library folder.
        guard !components.contains("..") else { throw AgentToolError("The subfolder must not contain \"..\".") }
        let move = arguments["mode"]?.stringValue == "move"

        let root: URL?
        if RemoteFolder.isRemote(key) {
            root = try await RemoteFolder.folder(for: key)
        } else {
            root = library.folderURL(for: key)
        }
        guard let root else { throw AgentToolError("The folder \(library.displayName(for: key)) cannot be found.") }
        let folder = components.filter { $0 != "." }.reduce(root) { $0.appending(path: $1, directoryHint: .isDirectory) }
        let destination = folder.appending(path: source.lastPathComponent)
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw AgentToolError("\(destination.path) already exists. Nothing was changed.")
        }
        // Large videos take a while to copy, especially to a server, so it happens off the main thread.
        try await Task.detached {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if move {
                try FileManager.default.moveItem(at: source, to: destination)
            } else {
                try FileManager.default.copyItem(at: source, to: destination)
            }
        }.value
        Task { await library.refresh() }
        return "\(move ? "Moved" : "Copied") the file to \(destination.path). Arthub is scanning the library, so it shows up in a moment."
    }

    // MARK: - Lookup

    private func parse(_ id: String) throws -> (kind: String, key: String) {
        let parts = id.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { throw unknownKind(id) }
        return (parts[0], parts[1])
    }

    private func unknownKind(_ id: String) -> AgentToolError {
        AgentToolError("\"\(id)\" is not an id Arthub knows. Use an id from search_library, such as \"movie:27205\".")
    }

    private func libraryFile(_ key: String) throws -> LibraryFile {
        guard let file = library.files.first(where: { $0.id.uuidString == key }) else {
            throw AgentToolError("This item is no longer in the library. Search for it again.")
        }
        return file
    }

    private func albumArtist(of file: LibraryFile) -> String {
        guard let audio = file.audio else { return "" }
        return audio.albumArtist.isEmpty ? audio.artist : audio.albumArtist
    }

    private func albumKey(of file: LibraryFile) -> String {
        "\(albumArtist(of: file))\u{0}\(file.audio?.album ?? "")"
    }

    /// The album's tracks in disc and track order.
    private func albumTracks(of track: LibraryFile) -> [LibraryFile] {
        let key = albumKey(of: track)
        return library.files.filter { !$0.fileURL.isVideo && albumKey(of: $0) == key }.sorted(by: trackOrder)
    }

    /// The artist's songs, album by album.
    private func artistSongs(_ artist: String) -> [LibraryFile] {
        library.files.filter { $0.audio?.artist == artist || $0.audio?.albumArtist == artist }
            .sorted { albumKey(of: $0) == albumKey(of: $1) ? trackOrder($0, $1) : albumKey(of: $0) < albumKey(of: $1) }
    }

    private func trackOrder(_ lhs: LibraryFile, _ rhs: LibraryFile) -> Bool {
        let left = (lhs.audio?.discNumber ?? 1, lhs.audio?.trackNumber ?? .max)
        let right = (rhs.audio?.discNumber ?? 1, rhs.audio?.trackNumber ?? .max)
        return left == right ? lhs.fileURL.path < rhs.fileURL.path : left < right
    }

    private func movieFiles(_ key: String) -> [LibraryFile] {
        library.files.filter { $0.movie.map { String($0.id) } == key }
    }

    /// The show's episodes in season and episode order.
    private func showEpisodes(_ key: String) -> [LibraryFile] {
        library.files.filter { $0.series.map { String($0.id) } == key && $0.episode != nil }
            .sorted { ($0.episode!.seasonNumber, $0.episode!.episodeNumber) < ($1.episode!.seasonNumber, $1.episode!.episodeNumber) }
    }

    /// The last watched episode, or the one after it when it was watched to the end, or else the first.
    private func upNext(_ episodes: [LibraryFile]) -> LibraryFile? {
        let available = episodes.filter(\.isAvailable)
        let watched = available.compactMap { file -> (LibraryFile, UserMetrics)? in
            guard let episode = file.episode else { return nil }
            let metrics = WatchProgressStore.shared.metrics(.episode, tmdbID: episode.id)
            return metrics.watchedAt == nil ? nil : (file, metrics)
        }
        guard let latest = watched.max(by: { $0.1.watchedAt! < $1.1.watchedAt! }) else { return available.first }
        let last = latest.0
        guard last.duration > 0, latest.1.currentTime >= last.duration - 60,
              let index = available.firstIndex(where: { $0.id == last.id }), index + 1 < available.count else { return last }
        return available[index + 1]
    }

    // MARK: - Text

    private func field(_ name: String, _ value: String?) -> String {
        guard let value, !value.isEmpty else { return "" }
        return "\(name): \(value)"
    }

    private func titleWithYear(_ title: String, _ date: Date?) -> String {
        guard let date else { return title }
        return "\(title) (\(Calendar.current.component(.year, from: date)))"
    }

    private func episodeNumber(_ episode: TVEpisode) -> String {
        String(format: "S%02dE%02d", episode.seasonNumber, episode.episodeNumber)
    }

    private func progress(_ metrics: UserMetrics, duration: TimeInterval) -> String {
        guard metrics.watchedAt != nil, metrics.currentTime > 0 else { return "not watched" }
        return "watched to \(metrics.currentTime.formatted()) of \(duration.formatted())"
    }

    private func fileLines(_ file: LibraryFile) -> [String] {
        ["File: \(file.fileURL.path)\(file.isAvailable ? "" : " (offline)")",
         "Library folder: \(library.displayName(for: file.library))"]
    }
}

private struct AgentToolError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}
