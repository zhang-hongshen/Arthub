//
//  MediaNaming.swift
//  Arthub
//

import Foundation

/// Folder and file naming rules used to identify media and its sidecar files.
///
///     Movies/Inception (2010)/Inception (2010).mkv
///     Movies/Inception (2010)/Inception (2010) - 4K.mkv      (another version of the same movie)
///     Movies/Inception (2010)/Inception (2010).zh-Hans.srt
///     Movies/Inception (2010)/Trailers/Official Trailer.mp4
///     TV Shows/Doctor Who (2005)/Season 01/Doctor Who (2005) S01E01.mkv
///     TV Shows/Doctor Who (2005)/Specials/Doctor Who (2005) S00E01.mkv
///     Music/Artist/Album (2019)/Disc 1/01 Title.flac
///     Music/Artist/Album (2019)/01 Title.lrc
///     Music/Artist/01 Title.mp3              (album from the tags)
///
/// Periods, spaces, underscores and dashes are interchangeable separators.
enum MediaNaming {

    struct Movie: Equatable {
        var title: String
        var year: Int?
        var tmdbID: Int?
    }

    struct Episode: Equatable {
        var show: String
        var year: Int?
        var tmdbID: Int?
        var season: Int
        /// More than one number for multi-episode files such as `S01E01-E02`.
        var episodes: [Int]
        var episode: Int { episodes[0] }
    }

    enum Video: Equatable {
        case movie(Movie)
        case episode(Episode)
    }

    struct Track: Equatable {
        var title: String
        var trackNumber: Int?
        var discNumber: Int?
        var album: String?
        var year: Int?
        var artist: String?
    }

    struct Subtitle: Identifiable, Hashable {
        var url: URL
        var language: String?
        var isForced = false
        var isSDH = false
        var id: URL { url }

        var displayName: String {
            var name = language.flatMap { Locale.current.localizedString(forIdentifier: $0) }
                ?? url.deletingPathExtension().lastPathComponent
            if isForced { name += " (" + String(localized: "Forced") + ")" }
            if isSDH { name += " (SDH)" }
            return name
        }
    }

    static let subtitleExtensions: Set<String> = ["srt", "vtt", "webvtt", "ass", "ssa"]
    static let lyricsExtensions = ["lrc", "ttml"]
    private static let imageExtensions = ["jpg", "jpeg", "png"]
    private static let coverNames = ["cover", "folder", "front", "album", "albumart"]
    private static let subtitleFolders = ["Subs", "Subtitles"]
    private static let extraFolders: Set<String> = [
        "extras", "behind the scenes", "deleted scenes", "featurettes", "interviews",
        "scenes", "shorts", "trailers", "other", "others", "sample", "samples"
    ]
    private static let extraSuffixes = /(?i)-(behindthescenes|deleted|featurette|interview|scene|short|trailer|other)$|[\s._-]sample$/
    /// Library-level folders that never name a title, e.g. `TV Shows/` above the show folder.
    private static let containerFolders: Set<String> = [
        "movies", "movie", "films", "film", "tv", "tv shows", "tvshows", "tv series", "shows", "series",
        "anime", "videos", "video", "downloads", "media", "music", "documentaries",
        "电影", "电视剧", "剧集", "动漫", "动画", "视频", "音乐", "纪录片"
    ]
}

// MARK: Video

extension MediaNaming {

    /// Parses a video path into a movie or an episode. Episodes win when both readings are possible.
    static func parseVideo(_ url: URL, library: URL? = nil) -> Video? {
        if let episode = parseEpisode(url, library: library) { return .episode(episode) }
        return parseMovie(url, library: library).map(Video.movie)
    }

    /// Trailers, deleted scenes and other bonus material, by `-trailer` suffix or by folder.
    static func isExtra(_ url: URL, library: URL? = nil) -> Bool {
        if url.fileName.lowercased() == "sample" || url.fileName.contains(extraSuffixes) { return true }
        return folders(of: url, library: library).contains { extraFolders.contains($0.lowercased()) }
    }

    /// The folder that holds every season of the show `url` belongs to.
    static func showFolder(for url: URL, library: URL? = nil) -> URL? {
        var folder = url.deletingLastPathComponent()
        for name in folders(of: url, library: library) {
            if seasonNumber(folder: name) == nil { return folder }
            folder = folder.deletingLastPathComponent()
        }
        return nil
    }

    static func parseMovie(_ url: URL, library: URL? = nil) -> Movie? {
        var movie = parseMovie(name: url.fileName)
        // `Movies/Inception (2010)/movie.mkv`: a folder with a year is more reliable than a bare file name.
        if movie?.year == nil, movie?.tmdbID == nil,
           let folder = folders(of: url, library: library).first,
           !containerFolders.contains(folder.lowercased()), !extraFolders.contains(folder.lowercased()),
           let parsed = parseMovie(name: folder), parsed.year != nil || parsed.tmdbID != nil {
            movie = parsed
        }
        return movie
    }

    static func parseMovie(name: String) -> Movie? {
        let (stripped, tmdbID) = extractIDs(name)
        var name = stripped.replacing(/(?i)[\s._-]*(cd|disc|disk|dvd|part|pt)[\s._-]*\d{1,2}$/, with: "")
        name = normalizeSeparators(name)
        var year: Int?
        if let match = name.firstMatch(of: /[\(\[]((?:19|20)\d{2})[\)\]]/) {
            year = Int(match.output.1)
            name = String(name[..<match.range.lowerBound])
        } else if let match = name.matches(of: /\s((?:19|20)\d{2})(?=\s|$)/).last {
            // A leading number is part of the title: `2012 2009`, `1917`.
            year = Int(match.output.1)
            name = String(name[..<match.range.lowerBound])
        }
        let title = cleanTitle(name)
        guard !title.isEmpty else { return nil }
        return Movie(title: title, year: year, tmdbID: tmdbID)
    }

    static func parseEpisode(_ url: URL, library: URL? = nil) -> Episode? {
        let names = folders(of: url, library: library)
        let folderSeason = names.lazy.compactMap(seasonNumber(folder:)).first
        let (fileName, fileID) = extractIDs(url.fileName)
        var prefix = ""
        var season: Int?
        var episodes: [Int] = []

        if let match = fileName.firstMatch(of: seasonEpisodePattern) {
            prefix = String(fileName[..<match.range.lowerBound])
            season = Int(match.output.season)
            episodes = [Int(match.output.episode)].compactMap { $0 }
            episodes += match.output.more.matches(of: /\d{1,4}/).compactMap { Int($0.output) }
        } else if let match = fileName.firstMatch(of: crossPattern) {
            prefix = String(fileName[..<match.range.lowerBound])
            season = Int(match.output.season)
            episodes = [Int(match.output.episode)].compactMap { $0 }
        } else if let folderSeason {
            // Inside a season folder the file name only needs the episode number.
            season = folderSeason
            if let match = fileName.firstMatch(of: /(?i)(?:^|[\s._\-\[])(?:e|ep|episode)[\s._-]*(\d{1,4})(?=$|[\s._\-\]])/) {
                episodes = [Int(match.output.1)].compactMap { $0 }
            } else if let match = fileName.firstMatch(of: /第\s*(\d{1,4})\s*[集话話]/) {
                episodes = [Int(match.output.1)].compactMap { $0 }
            } else if let match = fileName.wholeMatch(of: /(\d{1,2})[.\-](\d{1,4})(?:[\s._-].*)?/) {
                // `1-02 Name` or `01.02 Name`
                season = Int(match.output.1)
                episodes = [Int(match.output.2)].compactMap { $0 }
            } else if let match = fileName.wholeMatch(of: /(\d{1,4})(?:[\s._-].*)?/) {
                episodes = [Int(match.output.1)].compactMap { $0 }
            }
        } else if names.count > 0, let match = fileName.wholeMatch(of: /(\d{1,2})\.(\d{1,4})(?:[\s._-].*)?/) {
            // `Show/any folder/01.02 Name`
            season = Int(match.output.1)
            episodes = [Int(match.output.2)].compactMap { $0 }
        }
        guard let season, let first = episodes.first else { return nil }
        episodes = [first] + episodes.dropFirst().filter { $0 > first }

        var show = parseShow(name: prefix)
        if show.tmdbID == nil { show.tmdbID = fileID }
        // A show folder keeps every episode of the show together even when file names disagree.
        if let folder = showFolderName(names, library: library), folderSeason != nil || show.title.isEmpty {
            let parsed = parseShow(name: folder)
            if !parsed.title.isEmpty || parsed.tmdbID != nil {
                show = Movie(title: parsed.title.isEmpty ? show.title : parsed.title,
                             year: parsed.year ?? show.year, tmdbID: parsed.tmdbID ?? show.tmdbID)
            }
        }
        guard !show.title.isEmpty || show.tmdbID != nil else { return nil }
        return Episode(show: show.title, year: show.year, tmdbID: show.tmdbID, season: season, episodes: episodes)
    }

    // s01e02, s01.e02, s1e2, se1.ep2, season1.episode2, S01 E01-E02
    private static let seasonEpisodePattern =
        /(?i)(?:^|[\s._\-\[\(])(?:s|se|season)[\s._-]*(?<season>\d{1,3})[\s._-]*(?:e|ep|episode)[\s._-]*(?<episode>\d{1,4})(?<more>(?:[\s._]*-?[\s._]*e\d{1,4}|-\d{1,4})*)(?=$|[^0-9a-z])/
    // 1x02 (not 1920x1080)
    private static let crossPattern = /(?i)(?:^|[\s._\-\[])(?<season>\d{1,2})x(?<episode>\d{2,3})(?=$|[\s._\-\]])/

    private static func parseShow(name: String) -> Movie {
        let (name, tmdbID) = extractIDs(name)
        var title = normalizeSeparators(name)
        // Release folders such as `Show.S01.1080p`
        title = title.replacing(/(?i)\s(s|season)\s?\d{1,3}(\s.*)?$/, with: "")
        var year: Int?
        if let match = title.firstMatch(of: /[\(\[]((?:19|20)\d{2})[\)\]]/) ?? title.firstMatch(of: /\s((?:19|20)\d{2})$/) {
            year = Int(match.output.1)
            title.removeSubrange(match.range)
        }
        return Movie(title: cleanTitle(title), year: year, tmdbID: tmdbID)
    }

    /// The show name folder: the one above the nearest season folder, else the outermost named folder.
    private static func showFolderName(_ names: [String], library: URL?) -> String? {
        let usable = { (name: String) in
            !containerFolders.contains(name.lowercased()) && !extraFolders.contains(name.lowercased())
                && seasonNumber(folder: name) == nil
        }
        if let index = names.firstIndex(where: { seasonNumber(folder: $0) != nil }) {
            return names[(index + 1)...].first(where: usable)
                ?? library.map(\.lastPathComponent).flatMap { usable($0) ? $0 : nil }
        }
        // Without a library root the outer folders are unrelated to the media.
        return library == nil ? names.first(where: usable) : names.last(where: usable)
    }

    /// `Season 1`, `S01`, `Series 2`, `Specials`, `第一季`
    static func seasonNumber(folder: String) -> Int? {
        let name = folder.trimmingCharacters(in: .whitespaces)
        if name.wholeMatch(of: /(?i)specials?|sp|特别篇|特別篇/) != nil { return 0 }
        if let match = name.wholeMatch(of: /(?i)(?:season|series|staffel|saison|temporada|s)[\s._-]*(\d{1,3})/) {
            return Int(match.output.1)
        }
        if let match = name.wholeMatch(of: /第\s*([0-9零一二三四五六七八九十]+)\s*季/) {
            return Int(match.output.1) ?? chineseNumber(String(match.output.1))
        }
        return nil
    }

    /// `{tmdb-27205}` pins a TMDb ID; `{imdb-…}` and `{edition-…}` are labels only.
    private static func extractIDs(_ name: String) -> (String, Int?) {
        var tmdbID: Int?
        if let match = name.firstMatch(of: /(?i)[\{\[]tmdb(?:id)?[-=](\d+)[\}\]]/) { tmdbID = Int(match.output.1) }
        return (name.replacing(/\s*\{[^}]*\}/, with: ""), tmdbID)
    }

    private static func normalizeSeparators(_ name: String) -> String {
        let name = name.replacing(/^\s*\[[^\]]*\]\s*/, with: "")
        // `Captain-America-2014` uses dashes as spaces; `Spider-Man (2002)` does not.
        return name.contains(" ") ? name.replacing(/[._]/, with: " ") : name.replacing(/[._\-]/, with: " ")
    }

    private static func cleanTitle(_ name: String) -> String {
        var title = name
        // Release details and edition labels are not part of the title.
        title = title.replacing(/(?i)\s(2160p|1080[pi]|720p|576p|480p|4k|uhd|hdr10\+?|hdr|dolby\s?vision|bluray|blu\sray|bdrip|brrip|bdremux|remux|web\s?dl|webrip|web|hdtv|dvdrip|x26[45]|h\s?26[45]|hevc|avc|aac|ac3|dts|atmos|10bit|proper|repack|multi|subbed|dubbed)(\s.*)?$/, with: "")
        title = title.replacing(/(?i)\s(director'?s|extended|theatrical|cinematic|final|unrated|tv)\scut\b|\suncut\b|\s(special|ultimate)\sedition\b|\sblack\s?&\s?white\b|\s(wide|full)\sscreen\b|\simax\b/, with: "")
        title = title.replacing(/[\(\[]\s*[\)\]]/, with: "")
        title = title.replacing(/\s{2,}/, with: " ")
        return title.trimmingCharacters(in: CharacterSet(charactersIn: " -_.([")).trimmingCharacters(in: .whitespaces)
    }

    private static func chineseNumber(_ text: String) -> Int? {
        let digits: [Character: Int] = ["零": 0, "一": 1, "二": 2, "三": 3, "四": 4, "五": 5,
                                        "六": 6, "七": 7, "八": 8, "九": 9]
        if let index = text.firstIndex(of: "十") {
            let tens: Int? = text[..<index].isEmpty ? 1 : digits[text[text.startIndex]]
            let ones = text[text.index(after: index)...].first.flatMap { digits[$0] } ?? 0
            return tens.map { $0 * 10 + ones }
        }
        return text.count == 1 ? digits[text[text.startIndex]] : nil
    }
}

// MARK: Versions

extension MediaNaming {

    /// The version a file name gives after the title, as Infuse and Plex name them:
    ///
    ///     Inception (2010) - 4K.mkv                 4K
    ///     Inception (2010) - Director's Cut.mkv     Director's Cut
    ///     Inception (2010) {edition-Extended}.mkv   Extended
    ///
    /// The dash must follow the bracketed year, so `Mission Impossible - Fallout (2018)` has no version.
    static func versionName(_ url: URL) -> String? {
        let name = url.fileName
        if let match = name.firstMatch(of: /(?i)\{edition-([^}]+)\}/) { return String(match.output.1) }
        let stripped = name.replacing(/\s*\{[^}]*\}/, with: "")
        guard let match = stripped.firstMatch(of: /[\)\]]\s+-\s+(.+)$/) else { return nil }
        return match.output.1.trimmingCharacters(in: .whitespaces)
    }

    /// The file name without its version, e.g. `Inception (2010)` for `Inception (2010) - 4K`,
    /// so every version finds the subtitles and artwork named after the movie.
    static func nameWithoutVersion(_ url: URL) -> String {
        let name = url.fileName.replacing(/(?i)\s*\{edition-[^}]+\}/, with: "")
        guard let match = name.firstMatch(of: /[\)\]]\s+-\s+.+$/) else { return name }
        return String(name[...match.range.lowerBound])
    }

    /// The picture width a release name implies: `2160p` or `4K` is 3840, `1080p` is 1920.
    static func videoWidth(named name: String) -> Int? {
        guard let match = name.firstMatch(of: /(?i)(?:^|[\s._\-\[\(])(2160p|4k|uhd|1440p|1080[pi]|720p|576p|480p)(?=$|[\s._\-\]\)])/) else {
            return nil
        }
        return switch match.output.1.lowercased() {
        case "2160p", "4k", "uhd": 3840
        case "1440p": 2560
        case "1080p", "1080i": 1920
        case "720p": 1280
        case "576p": 720
        default: 640
        }
    }
}

// MARK: Music

extension MediaNaming {

    /// `Artist/Album (Year)/[Disc 1/]01 Title.ext`, or `Artist/01 Title.ext` when the tags name an album
    /// the nearest folder doesn't. Embedded tags take precedence over these values.
    static func parseTrack(_ url: URL, library: URL? = nil, album taggedAlbum: String? = nil) -> Track {
        var names = folders(of: url, library: library)
        var track = Track(title: url.fileName)
        if let first = names.first, let disc = discNumber(folder: first) {
            track.discNumber = disc
            names.removeFirst()
        }
        if let match = url.fileName.wholeMatch(of: /(?:(?<disc>\d{1,2})-)?(?<track>\d{1,3})(?:\s*[-._]\s*|\s+)(?<title>.+)/) {
            track.title = String(match.output.title).trimmingCharacters(in: .whitespaces)
            track.trackNumber = Int(match.output.track)
            if let disc = match.output.disc { track.discNumber = Int(disc) }
        }
        var named = names.filter { !containerFolders.contains($0.lowercased()) }
        if let folder = named.first {
            let album = parseAlbum(folder: folder)
            if taggedAlbum.map({ isAlbum(album.title, named: $0) }) ?? true {
                track.album = album.title; track.year = album.year
                named.removeFirst()
            }
        }
        track.artist = named.first
        return track
    }

    /// `Album (2019)`, `Album [2019]`, `2019 - Album` or `Album`.
    private static func parseAlbum(folder: String) -> (title: String, year: Int?) {
        if let match = folder.wholeMatch(of: /(.+?)\s*[\(\[]((?:19|20)\d{2})[\)\]]/) {
            return (String(match.output.1), Int(match.output.2))
        }
        if let match = folder.wholeMatch(of: /((?:19|20)\d{2})\s*-\s*(.+)/) {
            return (String(match.output.2), Int(match.output.1))
        }
        return (folder, nil)
    }

    /// Ignores case, punctuation and extra words, e.g. `Album (Deluxe)` names `Album`.
    private static func isAlbum(_ folder: String, named album: String) -> Bool {
        let key = { (text: String) in String(text.lowercased().unicodeScalars.filter(CharacterSet.alphanumerics.contains)) }
        let folder = key(folder), album = key(album)
        guard !folder.isEmpty, !album.isEmpty else { return true }
        return folder.contains(album) || album.contains(folder)
    }

    /// `Disc 1`, `CD2`, `Disk 3`
    static func discNumber(folder: String) -> Int? {
        folder.wholeMatch(of: /(?i)(?:cd|disc|disk)[\s._-]*(\d{1,2})/).flatMap { Int($0.output.1) }
    }

    /// `Song.lrc` / `Song.ttml` next to the audio file or in a `Lyrics` folder.
    static func lyrics(for url: URL, title: String? = nil) -> URL? {
        let folder = url.deletingLastPathComponent()
        let names = [url.deletingPathExtension().lastPathComponent, title].compactMap { $0 }.filter { !$0.isEmpty }
        for directory in [folder, folder.appending(path: "Lyrics")] {
            for name in names {
                for ext in lyricsExtensions {
                    let candidate = directory.appending(path: name).appendingPathExtension(ext)
                    if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
                }
            }
        }
        return nil
    }

    /// `cover.jpg`, `folder.jpg` or `front.jpg` in the album (or disc) folder.
    static func cover(for url: URL) -> URL? {
        var directories = [url.deletingLastPathComponent()]
        if discNumber(folder: directories[0].lastPathComponent) != nil {
            directories.append(directories[0].deletingLastPathComponent())
        }
        return image(named: coverNames, in: directories)
    }

    private static func image(named names: [String], in directories: [URL]) -> URL? {
        for directory in directories {
            for name in names {
                for ext in imageExtensions {
                    let candidate = directory.appending(path: name).appendingPathExtension(ext)
                    if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
                }
            }
        }
        return nil
    }
}

// MARK: Artwork

extension MediaNaming {

    struct Artwork: Codable, Equatable {
        var poster: URL?
        var backdrop: URL?
        var seasonPoster: URL?
        var thumbnail: URL?
    }

    /// Infuse-style local artwork for a video:
    ///
    ///     Movies/Inception (2010)/Inception (2010).jpg          poster.jpg  folder.jpg
    ///     Movies/Inception (2010)/Inception (2010)-fanart.jpg   fanart.jpg  backdrop.jpg
    ///     TV Shows/Doctor Who (2005)/poster.jpg  fanart.jpg  Season01.jpg  season-specials-poster.jpg
    ///     TV Shows/Doctor Who (2005)/Season 01/poster.jpg
    ///     TV Shows/Doctor Who (2005)/Season 01/Doctor Who (2005) S01E01.jpg  (-thumb.jpg)
    ///
    /// `images` maps the lowercased paths of the library's image files to their URLs,
    /// so the lookup is case-insensitive and touches no disk.
    static func artwork(for video: URL, library: URL?, images: [String: URL]) -> Artwork {
        func find(_ names: [String], in folder: URL) -> URL? {
            for name in names {
                for ext in imageExtensions {
                    let path = folder.appending(path: name).appendingPathExtension(ext).standardizedFileURL.path
                    if let url = images[path.lowercased()] { return url }
                }
            }
            return nil
        }
        let folder = video.deletingLastPathComponent()
        let base = video.deletingPathExtension().lastPathComponent
        // Folder-wide names such as `poster.jpg` never belong to a file loose in the library root.
        let isRoot = { (url: URL) in library?.standardizedFileURL.path == url.standardizedFileURL.path }
        let posterNames = ["poster", "folder", "cover"]
        let backdropNames = ["fanart", "backdrop", "background"]
        var artwork = Artwork()
        switch parseVideo(video, library: library) {
        case .episode(let episode):
            let show = showFolder(for: video, library: library) ?? folder
            artwork.thumbnail = find([base, base + "-thumb"], in: folder)
            if !isRoot(show) {
                artwork.poster = find(posterNames, in: show)
                artwork.backdrop = find(backdropNames, in: show)
                let number = String(format: "%02d", episode.season)
                var names = ["season\(number)-poster", "season\(number)", "season \(number)"]
                if episode.season == 0 { names = ["season-specials-poster", "specials"] + names }
                artwork.seasonPoster = find(names, in: show)
            }
            if artwork.seasonPoster == nil, folder != show, !isRoot(folder) {
                artwork.seasonPoster = find(posterNames, in: folder)
            }
        case .movie, nil:
            let plain = nameWithoutVersion(video)
            artwork.poster = find([base, base + "-poster", plain, plain + "-poster"], in: folder)
                ?? (isRoot(folder) ? nil : find(posterNames, in: folder))
            artwork.backdrop = find([base + "-fanart", base + "-backdrop", plain + "-fanart", plain + "-backdrop"], in: folder)
                ?? (isRoot(folder) ? nil : find(backdropNames, in: folder))
        }
        return artwork
    }
}

// MARK: Subtitles

extension MediaNaming {

    /// Sidecar subtitles for a video:
    ///
    ///     Movie.srt  Movie.en.srt  Movie.zh-Hans.forced.srt  Movie.eng.sdh.srt
    ///     Subs/Movie.en.srt  Subs/Movie/2_English.srt
    ///
    /// Files in `Subs/` need not repeat the video name when it is the only video in its folder.
    /// Versions such as `Movie - 4K.mkv` also find the subtitles named after `Movie`.
    static func subtitles(for video: URL) -> [Subtitle] {
        let manager = FileManager.default
        let directory = video.deletingLastPathComponent()
        let base = video.deletingPathExtension().lastPathComponent
        let bases = Set([base, nameWithoutVersion(video)].map { $0.lowercased() })
        let siblings = (try? manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil,
                                                         options: .skipsHiddenFiles)) ?? []
        let isOnlyVideo = siblings.filter(\.isVideo).count <= 1
        var found: [URL: Subtitle] = [:]

        func scan(_ items: [URL], requireName: Bool) {
            for item in items where subtitleExtensions.contains(item.pathExtension.lowercased()) {
                let name = item.deletingPathExtension().lastPathComponent
                let tags: String
                if bases.contains(name.lowercased()) {
                    tags = ""
                } else if let base = bases.first(where: { name.lowercased().hasPrefix($0 + ".") }) {
                    tags = String(name.dropFirst(base.count + 1))
                } else if !requireName {
                    tags = name
                } else { continue }
                found[item.standardizedFileURL] = subtitle(url: item, tags: tags)
            }
        }

        scan(siblings, requireName: true)
        for folderName in subtitleFolders {
            let folder = directory.appending(path: folderName)
            let items = (try? manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil,
                                                          options: .skipsHiddenFiles)) ?? []
            scan(items, requireName: !isOnlyVideo)
            let episodeFolder = folder.appending(path: base)
            scan((try? manager.contentsOfDirectory(at: episodeFolder, includingPropertiesForKeys: nil,
                                                   options: .skipsHiddenFiles)) ?? [], requireName: false)
        }
        return found.values.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    /// Forced subtitles first, then the first track in a preferred language,
    /// then a lone untagged `Movie.srt`.
    static func preferredSubtitle(in subtitles: [Subtitle]) -> Subtitle? {
        let preferred = Locale.preferredLanguages.map { Locale.Language(identifier: $0) }
        func matches(_ subtitle: Subtitle) -> Bool {
            guard let language = subtitle.language.map(Locale.Language.init(identifier:)) else { return false }
            return preferred.contains {
                $0.languageCode == language.languageCode && (language.script == nil || $0.script == nil || $0.script == language.script)
            }
        }
        return subtitles.first { $0.isForced && matches($0) }
            ?? subtitles.first { !$0.isForced && matches($0) }
            ?? (subtitles.count == 1 && subtitles[0].language == nil ? subtitles[0] : nil)
    }

    private static func subtitle(url: URL, tags: String) -> Subtitle {
        var subtitle = Subtitle(url: url)
        for token in tags.split(whereSeparator: { ".,_ ".contains($0) }).map({ $0.lowercased() }) {
            switch token {
            case "forced": subtitle.isForced = true
            case "sdh", "cc", "hi": subtitle.isSDH = true
            case "default": break
            default:
                if subtitle.language == nil { subtitle.language = languageIdentifier(token) }
            }
        }
        return subtitle
    }

    private static let languageAliases: [String: String] = [
        "chs": "zh-Hans", "sc": "zh-Hans", "gb": "zh-Hans", "简体": "zh-Hans", "简中": "zh-Hans", "简体中文": "zh-Hans",
        "cht": "zh-Hant", "tc": "zh-Hant", "big5": "zh-Hant", "繁体": "zh-Hant", "繁中": "zh-Hant", "繁體": "zh-Hant",
        "chi": "zh", "zho": "zh", "chinese": "zh", "中文": "zh", "双语": "zh", "chs&eng": "zh-Hans",
        "eng": "en", "english": "en", "英文": "en", "jpn": "ja", "japanese": "ja", "日文": "ja",
        "kor": "ko", "korean": "ko", "韩文": "ko", "fre": "fr", "fra": "fr", "ger": "de", "deu": "de",
        "spa": "es", "ita": "it", "por": "pt", "rus": "ru"
    ]

    private static func languageIdentifier(_ token: String) -> String? {
        if let alias = languageAliases[token] { return alias }
        if token.count > 3, !token.contains("-") {
            // Full English names, e.g. `French`.
            let english = Locale(identifier: "en")
            return Locale.LanguageCode.isoLanguageCodes.first {
                english.localizedString(forLanguageCode: $0.identifier)?.lowercased() == token
            }?.identifier
        }
        let language = Locale.Language(identifier: token)
        guard let code = language.languageCode, Locale.LanguageCode.isoLanguageCodes.contains(code) else { return nil }
        // `zh-hant` -> `zh-Hant`, `pt-br` -> `pt-BR`
        return [code.identifier, language.script?.identifier, language.region?.identifier]
            .compactMap { $0 }.joined(separator: "-")
    }
}

// MARK: Paths

extension MediaNaming {

    /// Folder names between the file and the library root, nearest first.
    static func folders(of url: URL, library: URL?) -> [String] {
        let parts = url.standardizedFileURL.deletingLastPathComponent().pathComponents
        if let root = library?.standardizedFileURL.pathComponents, parts.starts(with: root) {
            return parts.dropFirst(root.count).reversed()
        }
        return parts.dropFirst().reversed()
    }
}
