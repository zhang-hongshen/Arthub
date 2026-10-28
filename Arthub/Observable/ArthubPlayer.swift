//
//  ArthubPlayer.swift
//  Arthub
//
//  Created by 张鸿燊 on 12/3/2024.
//

import AVFoundation
import MediaPlayer

/// One file in the playlist, with what the system's Now Playing panel shows for it.
struct PlaylistItem {
    var id: Int
    var url: URL
    var title: String
    var artist: String? = nil
    var albumTitle: String? = nil
    var albumArtist: String? = nil
    var artwork: MPMediaItemArtwork? = nil
    /// The files the player can switch between, e.g. `4K` and `1080p`; `url` is the one playing.
    var versions: [MediaVersion] = []
}

/// Plays a playlist and keeps the system's Now Playing panel and media keys in sync.
/// `ArthubAudioPlayer` and `ArthubVideoPlayer` add what only music or video needs.
@Observable class ArthubPlayer {

    enum PlayerState {
        case stopped, playing, paused
    }

    enum PlayerMode {
        case noRepeat, repeatPlaylist, repeatItem
    }

    let player = AVPlayer()
    private(set) var playerState = PlayerState.stopped
    private(set) var playerMode = PlayerMode.noRepeat
    private(set) var items: [PlaylistItem] = []
    private(set) var currentIndex: Int?
    /// Updated every 0.25 s while playing.
    private(set) var currentTime: TimeInterval = 0

    var isPlaying: Bool { playerState == .playing }
    var isPlaylistEmpty: Bool { items.isEmpty }
    var currentItemID: Int? { currentIndex.map { items[$0].id } }
    var currentAssetURL: URL? { currentIndex.map { items[$0].url } }

    var duration: TimeInterval {
        let seconds = player.currentItem?.duration.seconds ?? 0
        return seconds.isFinite ? seconds : 0
    }

    /// The speed picked for playback. `player.rate` reads 0 while paused, so pickers bind to this.
    var playbackRate: Float = 1 {
        didSet {
            // `play()` resumes at `defaultRate`, so the picked speed outlasts a pause.
            player.defaultRate = playbackRate
            if isPlaying { player.rate = playbackRate }
        }
    }

    var volume: Float = 0.5 {
        didSet { player.volume = volume }
    }

    private let mediaType: MPNowPlayingInfoMediaType
    private var timeObserver: Any?
    private var rateObserver: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?

    init(mediaType: MPNowPlayingInfoMediaType) {
        self.mediaType = mediaType
        player.allowsExternalPlayback = true
    }

    // MARK: Playback

    /// Replaces the playlist. Nothing plays until `start(from:at:)`.
    func setPlaylist(_ items: [PlaylistItem]) {
        self.items = items
    }

    func start(from index: Int = 0, at time: TimeInterval = 0) {
        guard items.indices.contains(index) else { return }
        if playerState == .stopped { beginSession() }
        playerState = .playing
        playItem(at: index, from: time)
    }

    func stop() {
        guard playerState != .stopped else { return }
        player.pause()
        playerState = .stopped
        currentIndex = nil
        currentTime = 0
        endSession()
    }

    func play() {
        guard playerState == .paused else { return }
        playerState = .playing
        player.play()
    }

    func pause() {
        guard playerState == .playing else { return }
        playerState = .paused
        player.pause()
    }

    func togglePlayPause() {
        switch playerState {
        case .playing: pause()
        case .paused: play()
        case .stopped: start(from: currentIndex ?? 0)
        }
    }

    func nextTrack() {
        guard playerState != .stopped else { return }
        if let index = nextIndex() {
            playItem(at: index)
        } else {
            stop()
        }
    }

    /// The item after the current one, by the repeat mode; `nil` at the end of the playlist.
    func nextIndex() -> Int? {
        guard let currentIndex else { return nil }
        switch playerMode {
        case .noRepeat: return currentIndex + 1 < items.count ? currentIndex + 1 : nil
        case .repeatPlaylist: return (currentIndex + 1) % items.count
        case .repeatItem: return currentIndex
        }
    }

    /// Goes back to the start of the item, or to the item before when already near its start.
    func previousTrack() {
        guard playerState != .stopped, let currentIndex else { return }
        guard currentTime < 3 else { seek(to: 0); return }
        switch playerMode {
        case .noRepeat where currentIndex > 0: playItem(at: currentIndex - 1)
        case .repeatPlaylist: playItem(at: (currentIndex - 1 + items.count) % items.count)
        default: seek(to: 0)
        }
    }

    func nextPlayerMode() {
        playerMode = switch playerMode {
        case .noRepeat: .repeatPlaylist
        case .repeatPlaylist: .repeatItem
        case .repeatItem: .noRepeat
        }
    }

    func seek(to time: TimeInterval) {
        guard playerState != .stopped else { return }
        // A whole-second timescale would round a tapped lyric line onto its neighbour.
        player.seek(to: CMTime(seconds: time, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            if finished { self?.updateNowPlayingPlayback() }
        }
    }

    /// Plays another version of the current item from where playback is now.
    func switchVersion(to url: URL) {
        guard playerState != .stopped, let currentIndex, items[currentIndex].url != url else { return }
        let time = player.currentTime().seconds
        items[currentIndex].url = url
        playItem(at: currentIndex, from: time.isFinite ? time : currentTime)
    }

    func skip(by seconds: TimeInterval) {
        seek(to: player.currentTime().seconds + seconds)
    }

    private func playItem(at index: Int, from time: TimeInterval = 0) {
        let item = AVPlayerItem(url: items[index].url)
        player.replaceCurrentItem(with: item)
        currentIndex = index
        currentTime = time
        seek(to: time)
        if isPlaying { player.play() }
        updateNowPlayingItem()

        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main) { [weak self] _ in
            self?.nextTrack()
        }
    }

    // MARK: Session

    private func beginSession() {
        #if !os(macOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            self?.handleInterruption(notification)
        }
        #endif
        setUpRemoteCommands()
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
        }
        rateObserver = player.observe(\.rate) { [weak self] _, _ in
            self?.updateNowPlayingPlayback()
        }
    }

    private func endSession() {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
        rateObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        #if os(macOS)
        MPNowPlayingInfoCenter.default().playbackState = .stopped
        #else
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }
        interruptionObserver = nil
        try? AVAudioSession.sharedInstance().setActive(false)
        #endif
    }

    #if !os(macOS)
    /// A phone call or another app took the audio.
    private func handleInterruption(_ notification: Notification) {
        guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt else { return }
        if type == AVAudioSession.InterruptionType.began.rawValue {
            pause()
        } else if let options = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt,
                  AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume) {
            play()
        }
    }
    #endif

    // MARK: Media Keys and Now Playing

    /// The commands the media keys, Control Center and headphones can send. Subclasses add their own.
    func setUpRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        for command in [center.playCommand, center.pauseCommand, center.togglePlayPauseCommand,
                        center.nextTrackCommand, center.previousTrackCommand,
                        center.skipForwardCommand, center.skipBackwardCommand,
                        center.changePlaybackPositionCommand, center.changePlaybackRateCommand] {
            command.removeTarget(nil)
            command.isEnabled = false
        }
        handle(center.playCommand) { _ in self.play() }
        handle(center.pauseCommand) { _ in self.pause() }
        handle(center.togglePlayPauseCommand) { _ in self.togglePlayPause() }
        handle(center.changePlaybackPositionCommand) { event in
            if let event = event as? MPChangePlaybackPositionCommandEvent { self.seek(to: event.positionTime) }
        }
    }

    func handle(_ command: MPRemoteCommand, action: @escaping (MPRemoteCommandEvent) -> Void) {
        command.isEnabled = true
        command.addTarget { event in
            action(event)
            return .success
        }
    }

    private func updateNowPlayingItem() {
        guard let currentIndex else { return }
        let item = items[currentIndex]
        var info: [String: Any] = [
            MPNowPlayingInfoPropertyAssetURL: item.url,
            MPNowPlayingInfoPropertyMediaType: mediaType.rawValue,
            MPMediaItemPropertyTitle: item.title,
        ]
        info[MPMediaItemPropertyArtist] = item.artist
        info[MPMediaItemPropertyAlbumTitle] = item.albumTitle
        info[MPMediaItemPropertyAlbumArtist] = item.albumArtist
        info[MPMediaItemPropertyArtwork] = item.artwork
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// The system moves the elapsed time along by itself, so this is only needed when the rate or position jumps.
    private func updateNowPlayingPlayback() {
        guard playerState != .stopped, var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime().seconds
        info[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        #if os(macOS)
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
        #endif
    }
}
