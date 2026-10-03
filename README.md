<div align="center"><img alt="Arthub" height="200px" src="./logo.png" /></div>

## 💡What is Arthub?

Arthub is a native macOS app that aims to help you to manage your local media resources.It can identify movie, tv show and music from the library added automatically.

## :star: Key Features

🍔 Search metadata for each resource automatically

🍰 Support time-synced lyrics

🎬 **Movies** — automatically matched with TMDb metadata: posters, backdrops, logos, cast & crew, ratings, and trailers

📺 **TV Shows** — season/episode aware: `Show/Season 01/Show S01E01` files are grouped into shows, seasons and episodes with stills and air dates

🎵 **Music** — reads ID3/iTunes metadata for artist, album, composer, cover art and synced lyrics (`.lrc` / `.ttml` sidecar files or embedded lyrics)

💬 **Subtitles** — external `.srt` / `.vtt` / `.ass` subtitles next to the video, with language detection

⏯ **Players** — custom AVFoundation-based video and audio players with Now Playing integration, remote control support, playback-rate control, and resume-where-you-left-off

💾 **SwiftData persistence** — watch progress and watched history survive restarts

🚀 **Metadata cache** — matched TMDb entities are cached on disk, so rescans are instant and don't re-hit the API

🔍 **Live search** across titles, artists and albums

## Local Library Management

- **Files and folders** — browse added folders, search filenames, and open media even when no TMDb match is found. Unmatched videos have their own sidebar entry.
- **Saved matching** — search by title/year and choose a movie or TV show. For TV, specify season/episode and optionally apply the show to every episode in the show folder. Matches are saved per file and survive rescans and restarts.
- **Incremental refresh** — while the app is active, folders are checked every 30 seconds and when returning to the foreground. Only new or modified media is probed and automatically matched; Refresh remains available.
- **Offline folders** — unavailable folders and missing files retain their saved metadata. Playback is disabled until files return. Removing a library folder only removes its index entries, not the media on disk.
- **Moves** — on volumes that expose a volume UUID and file number, renaming or moving a file within the same volume preserves its identity and match. Copies and cross-volume moves are treated as new files.
- Folder access bookmarks are stored locally. The persistent index is stored in `Application Support/Arthub/Library.json`, separately from the expiring TMDb cache. Existing folders can be selected again with Add Folder to renew access.

Playback compatibility still depends on AVFoundation. These changes do not add a new decoding engine.

## 📁 Naming Conventions

Arthub identifies media from folder and file names, then matches it against TMDb. Periods, spaces, underscores and dashes are interchangeable separators, and release details (`1080p`, `BluRay`, `x264`, …) are ignored.

### Movies

```
Movies/
├── Pulp Fiction (1994).mkv
├── Captain-America-The-Winter-Soldier-2014.mp4
└── Inception (2010)/
    ├── Inception (2010).mkv
    ├── Inception (2010).srt              subtitles, same name as the video
    ├── Inception (2010).zh-Hans.srt      + language
    ├── Inception (2010).en.forced.srt    + language + forced / sdh
    ├── Subs/English.srt                  Subs/ or Subtitles/ folder
    └── Trailers/Official Trailer.mp4     extras are not matched as movies
```

- The year is optional but improves matching. If a file has no year, a parent folder named `Title (Year)` is used.
- `{tmdb-27205}` in the name pins the TMDb ID: `Inception {tmdb-27205}.mkv`.
- Edition and part labels are ignored: `Director's Cut`, `Extended Cut`, `IMAX`, `{edition-…}`, `cd1`, `part2`, …
- Extras: name suffixes `-trailer`, `-behindthescenes`, `-deleted`, `-featurette`, `-interview`, `-scene`, `-short`, `-other`, or folders `Trailers`, `Behind The Scenes`, `Deleted Scenes`, `Featurettes`, `Interviews`, `Scenes`, `Shorts`, `Extras`, `Other`.

### TV Shows

```
TV Shows/
└── Doctor Who (2005)/                    show folder (year / {tmdb-57243} optional)
    ├── Season 01/                        Season 1, S01, Series 1, 第一季
    │   ├── Doctor Who (2005) S01E01.mkv
    │   ├── Doctor Who (2005) S01E01.en.srt
    │   └── Doctor Who (2005) S01E02-E03.mkv   multi-episode file
    └── Specials/                         or Season 00
        └── Doctor Who (2005) S00E01.mkv
```

Accepted episode names:

```
show-name_s01.e02.mkv        show-name_s1e2.mkv          show-name_1x02.mkv
show-name_se1.ep2.mkv        show-name-season1.episode2.mkv
Show/any folder/S01E02.mkv   Show/any folder/01.02 Name.mkv
Show/Season 1/02 Name.mkv    Show/Season 1/1-02 Name.mkv   Show/Season 1/episode 02 - Name.mkv
Show/第一季/第02集.mkv
```

**Grouping a show.** Episodes are grouped by the TMDb series they match. Inside `Show/Season N/`, the show folder name is used for every episode, so differently named files still end up in the same show. Without season folders, the name before `S01E02` is used, falling back to the outermost show folder. Specials use season `00`; anime and miniseries also need a season number (`S01E210`). Matching a show manually can apply it to every episode under the same show folder.

### Music

```
Music/
└── Adele/                               artist
    └── 25 (2015)/                       album (year optional)
        ├── cover.jpg                    folder.jpg / front.jpg also work
        ├── Disc 1/                      CD1 / Disk 1 for multi-disc albums
        │   ├── 01 Hello.flac            or 1-01 Hello.flac
        │   └── 01 Hello.lrc             lyrics, same name as the song
        └── Lyrics/02 Send My Love.ttml
```

Embedded tags (ID3 / iTunes) take precedence; the path only fills missing title, track, disc, album, artist, year and cover. Lyrics are `.lrc` (including word timing) or `.ttml`, named after the audio file or the song title, next to it or in a `Lyrics/` folder.

### Subtitles

`.srt`, `.vtt`, `.ass` and `.ssa` files are found next to the video when they start with the video's name, or in a `Subs/` / `Subtitles/` folder (`Subs/<video name>/…` for episodes). Language tags such as `en`, `eng`, `English`, `zh-Hans`, `chs`, `cht` and the `forced` / `sdh` flags are recognized. A forced or preferred-language track is selected automatically and can be changed from the player controls. UTF-8, UTF-16, GB18030 and Big5 encodings are supported.

## 🛠 Build

```bash
git clone https://github.com/zhang-hongshen/Arthub.git
open Arthub/Arthub.xcodeproj
```

Set your TMDb API key (`tmdb_api_key`) in the scheme's environment variables and run.

## 📜 License

MIT
