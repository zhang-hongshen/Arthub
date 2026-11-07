# Arthub

<p align="center"><img src="logo.png" alt="Arthub" width="160" /></p>

Native macOS media library and player for movies, TV shows and music, with automatic metadata matching.

## Features

- Organize movies, TV shows and music with automatic metadata matching and artwork.
- Group multiple files for the same movie or episode into selectable versions.
- Play video and audio with subtitles, synchronized lyrics and saved watch progress.
- Browse local and remote folders, search the library, and retain metadata for offline media.
- Expose media-library tools to local AI agents through MCP.

## Requirements

- macOS 14 or later.
- Xcode 27 or later to build from source.

## Installation

Download the DMG from [GitHub Releases](https://github.com/zhang-hongshen/Arthub/releases), open it, and move Arthub to Applications. For an ad-hoc signed build, macOS may require approval in System Settings → Privacy & Security.

## Getting started

1. Add media folders in Settings and let Arthub scan their contents.
2. Browse Movies, TV Shows, Music or Files; correct a match when needed.
3. Choose a media version and start playback.

## Build from source

Open `Arthub.xcodeproj` in Xcode, select the `Arthub` scheme and My Mac, resolve its Swift packages, then build and run.

## Releases

Pushing an annotated version tag triggers the release workflow. Release titles contain only the version number; release notes contain only the numbered feature list from the tag body.

## License

See [LICENSE](LICENSE).
