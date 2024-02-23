//
//  ArthubAudioPlayer.swift
//  Arthub
//
//  Created by 张鸿燊 on 22/2/2024.
//

import AVFoundation
import MediaPlayer
#if os(macOS)
import AppKit
#endif

@Observable
class ArthubAudioPlayer: ObservableObject {
    
    private(set) var playerState: PlayerState = .stopped
    
    var currentIndex: Int? {
        guard let currentItem = player.currentItem else { return nil }
        guard let currentIndex = playerItems.firstIndex(where: { $0 == currentItem }) else { return nil }
        return currentIndex
    }
    
    var currentItem: AVPlayerItem? {
        guard let currentItem = player.currentItem else { return nil }
        return currentItem
    }
    
    private(set) var currentTime: TimeInterval = 0
    
    var duration: TimeInterval  {
        guard currentItem?.status == .readyToPlay else {
            return 0
        }
        return currentItem?.duration.seconds ?? 0
    }
    
    var volume: Float = 0.5 {
        didSet {
            self.player.volume = volume.clamp(to: 0...1)
        }
    }
    
    var rate: Float = 1 {
        didSet {
            self.player.rate = rate
        }
    }
    
    // Possible values of the `playerState` property.
    
    enum PlayerState {
        case stopped
        case playing
        case paused
    }
    
    // The app-supplied object that provides `NowPlayable`-conformant behavior.
    
    private let nowPlayableBehavior: NowPlayable
    
    // The player actually being used for playback. An app may use any system-provided
    // player, or may play content in any way that is wishes, provided that it uses
    // the NowPlayable behavior correctly.
    
    private var player: AVQueuePlayer = AVQueuePlayer(playerItem: nil)
    
    // A playlist of items to play.
    
    private var playerItems: [AVPlayerItem] = []
    
    // Metadata for each item.
    
    private var staticMetadatas: [NowPlayableStaticMetadata] = []
    
    // The internal state of this AssetPlayer separate from the state
    // of its AVQueuePlayer.
    
    // `true` if the current session has been interrupted by another app.
    
    private var isInterrupted: Bool = false
    
    // Private observers of notifications and property changes.
    
    private var itemObserver: NSKeyValueObservation!
    private var rateObserver: NSKeyValueObservation!
    private var statusObserver: NSObjectProtocol!
    
    
    private static let mediaSelectionKey = "availableMediaCharacteristicsWithMediaSelectionOptions"

    init(_ nowPlayable: NowPlayable) {
        self.nowPlayableBehavior = nowPlayable
        player.allowsExternalPlayback = true
        
        // Construct lists of commands to be registered or disabled.
    }
    
    func setupItems(musics: [Music]) {
        var playableAssets: [NowPlayableStaticMetadata] = []
        musics.forEach { music in
            var artwork: MPMediaItemArtwork? = nil
            if let cover = music.album?.cover, let image = NSImage(contentsOf: cover) {
                artwork = MPMediaItemArtwork(boundsSize: image.size, requestHandler: { size in
                    return image
                })
            }
            let metadata = NowPlayableStaticMetadata(
                assetURL: music.url, mediaType: .audio, isLiveStream: false,
                title: music.title, artist: music.artists.formatted(),
                artwork: artwork, albumArtist: music.album?.artists.formatted(),
                albumTitle: music.album?.title)
            playableAssets.append(metadata)
        }
        
        self.staticMetadatas = playableAssets
        self.playerItems = playableAssets.map {
            AVPlayerItem(asset: AVAsset(url: $0.assetURL),
                         automaticallyLoadedAssetKeys: [ArthubAudioPlayer.mediaSelectionKey])
        }
        
        self.player.removeAllItems()
        playerItems.forEach { item in
            if player.canInsert(item, after: nil) {
                player.insert(item, after: nil)
            }
        }
    }
    
    func start() throws{
        // Start playing, if there is something to play.
        
        var registeredCommands : [NowPlayableCommand] = []
        var enabledCommands : [NowPlayableCommand] = []
        
        for group in nowPlayableBehavior.defaultCommandCollections {
            registeredCommands.append(contentsOf: group.commands.compactMap { $0.shouldRegister ? $0.command : nil })
            enabledCommands.append(contentsOf: group.commands.compactMap { $0.shouldDisable ? $0.command : nil })
        }
        // Configure the app for Now Playing Info and Remote Command Center behaviors.
        
        try nowPlayableBehavior.handleNowPlayableConfiguration(commands: registeredCommands,
                                                               disabledCommands: enabledCommands,
                                                               commandHandler: handleCommand(command:event:),
                                                               interruptionHandler: handleInterrupt(with:))
        
        if playerItems.isEmpty {
            return
        }
            
        // Start a playback session.
        
        try nowPlayableBehavior.handleNowPlayableSessionStart()
        
        // Observe changes to the current item and playback rate.
        
        if player.currentItem != nil {
            itemObserver = player.observe(\.currentItem, options: .initial) {
                [unowned self] _, _ in
                self.handlePlayerItemChange()
            }
            
            rateObserver = player.observe(\.rate, options: .initial) {
                [unowned self] _, _ in
                self.handlePlaybackChange()
            }
            statusObserver = player.observe(\.currentItem?.status, options: .initial) {
                [unowned self] _, _ in
                self.handlePlaybackChange()
            }
            player.addPeriodicTimeObserver(forInterval:
                    .init(seconds: 1, preferredTimescale: 1),
                                           queue: .main) { time in
                self.currentTime = time.seconds
            }
        }
        
        play()
    }
    
    // Stop the playback session.
    
    func optOut() {
        
        itemObserver = nil
        rateObserver = nil
        statusObserver = nil
        
        player.pause()
        player.removeAllItems()
        playerState = .stopped
        
        nowPlayableBehavior.handleNowPlayableSessionEnd()
    }
    
    // MARK: Now Playing Info
    
    // Helper method: update Now Playing Info when the current item changes.
    
    private func handlePlayerItemChange() {
        
        guard playerState != .stopped else { return }
        guard let currentItem = player.currentItem else { optOut(); return }
        guard let currentIndex = playerItems.firstIndex(where: { $0 == currentItem }) else { return }
        
        // Set the Now Playing Info from static item metadata.
        
        let metadata = staticMetadatas[currentIndex]
        
        nowPlayableBehavior.handleNowPlayableItemChange(metadata: metadata)
    }
    
    // Helper method: update Now Playing Info when playback rate or position changes.
    
    private func handlePlaybackChange() {
        
        guard playerState != .stopped else { return }
        guard let currentItem = player.currentItem else { optOut(); return }
        guard currentItem.status == .readyToPlay else { return }
        
        // Create language option groups for the asset's media selection,
        // and determine the current language option in each group, if any.
        
        // Note that this is a simple example of how to create language options.
        // More sophisticated behavior (including default values, and carrying
        // current values between player tracks) can be implemented by building
        // on the techniques shown here.
        
        let asset = currentItem.asset
        
        var languageOptionGroups: [MPNowPlayingInfoLanguageOptionGroup] = []
        var currentLanguageOptions: [MPNowPlayingInfoLanguageOption] = []
        switch asset.status(of: .availableMediaCharacteristicsWithMediaSelectionOptions) {
        case.loaded(let characteristics):
            for mediaCharacteristic in characteristics {
                guard mediaCharacteristic == .audible || mediaCharacteristic == .legible else {
                    continue
                }
                asset.loadMediaSelectionGroup(for: mediaCharacteristic) { mediaSelectionGroup, error in
                    guard let mediaSelectionGroup = mediaSelectionGroup else { return }
                    let languageOptionGroup = mediaSelectionGroup.makeNowPlayingInfoLanguageOptionGroup()
                    languageOptionGroups.append(languageOptionGroup)
                    
                    // If the media selection group has a current selection,
                    // create a corresponding language option.
                    
                    if let selectedMediaOption = currentItem.currentMediaSelection.selectedMediaOption(in: mediaSelectionGroup),
                        let currentLanguageOption = selectedMediaOption.makeNowPlayingInfoLanguageOption() {
                        currentLanguageOptions.append(currentLanguageOption)
                    }
                }
            }
        case .failed(let error):
            break
        case .loading:
            break
        case .notYetLoaded:
            break
        }
        
        // Construct the dynamic metadata, including language options for audio,
        // subtitle and closed caption tracks that can be enabled for the
        // current asset.
        
        let isPlaying = playerState == .playing
        let metadata = NowPlayableDynamicMetadata(rate: player.rate,
                                                  position: Float(currentItem.currentTime().seconds),
                                                  duration: Float(currentItem.duration.seconds),
                                                  currentLanguageOptions: currentLanguageOptions,
                                                  availableLanguageOptionGroups: languageOptionGroups)
        
        nowPlayableBehavior.handleNowPlayablePlaybackChange(playing: isPlaying, metadata: metadata)
    }
    
    // MARK: Playback Control
    
    // The following methods handle various playback conditions triggered by remote commands.
    
    private func play() {
        
        switch playerState {
            
        case .stopped:
            playerState = .playing
            player.play()
            
            handlePlayerItemChange()

        case .playing:
            break
            
        case .paused where isInterrupted:
            playerState = .playing
            
        case .paused:
            playerState = .playing
            player.play()
        }
    }
    
    private func pause() {
        
        switch playerState {
            
        case .stopped:
            break
            
        case .playing where isInterrupted:
            playerState = .paused
            
        case .playing:
            playerState = .paused
            player.pause()
            
        case .paused:
            break
        }
    }
    
    func togglePlayPause() {

        switch playerState {
            
        case .stopped:
            play()
            
        case .playing:
            pause()
            
        case .paused:
            play()
        }
    }
    
    func nextTrack() {
        
        if case .stopped = playerState { return }
        
        player.advanceToNextItem()
    }
    
    func previousTrack() {
        
        if case .stopped = playerState { return }
        
        let currentTime = player.currentTime().seconds
        let currentItems = player.items()
        let previousIndex = playerItems.count - currentItems.count - 1
        
        guard currentTime < 3, previousIndex > 0, previousIndex < playerItems.count else { seek(to: .zero); return }
        
        player.removeAllItems()
        
        for playerItem in playerItems[(previousIndex - 1)...] {
            
            if player.canInsert(playerItem, after: nil) {
                player.insert(playerItem, after: nil)
            }
        }
        
        if case .playing = playerState {
            player.play()
        }
    }
    
    func seek(to time: CMTime) {
        
        if case .stopped = playerState { return }
        
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) {
            isFinished in
            if isFinished {
                self.handlePlaybackChange()
            }
        }
    }
    
    func seek(to position: TimeInterval) {
        seek(to: CMTime(seconds: position, preferredTimescale: 1))
    }
    
    private func skipForward(by interval: TimeInterval) {
        seek(to: player.currentTime() + CMTime(seconds: interval, preferredTimescale: 1))
    }
    
    private func skipBackward(by interval: TimeInterval) {
        seek(to: player.currentTime() - CMTime(seconds: interval, preferredTimescale: 1))
    }
    
    private func setPlaybackRate(_ rate: Float) {
        
        if case .stopped = playerState { return }
        
        player.rate = rate
    }
    
    private func didEnableLanguageOption(_ languageOption: MPNowPlayingInfoLanguageOption) -> Bool {
        
        guard let currentItem = player.currentItem else { return false }
        guard let (mediaSelectionOption, mediaSelectionGroup) = enabledMediaSelection(for: languageOption) else { return false }
        
        currentItem.select(mediaSelectionOption, in: mediaSelectionGroup)
        handlePlaybackChange()
        
        return true
    }
    
    private func didDisableLanguageOption(_ languageOption: MPNowPlayingInfoLanguageOption) -> Bool {
        
        guard let currentItem = player.currentItem else { return false }
        guard let mediaSelectionGroup = disabledMediaSelection(for: languageOption) else { return false }

        guard mediaSelectionGroup.allowsEmptySelection else { return false }
        currentItem.select(nil, in: mediaSelectionGroup)
        handlePlaybackChange()
        
        return true
    }
    
    // Helper method to get the media selection group and media selection for enabling a language option.
    
    private func enabledMediaSelection(for languageOption: MPNowPlayingInfoLanguageOption) -> (AVMediaSelectionOption, AVMediaSelectionGroup)? {
        
        // In your code, you would implement your logic for choosing a media selection option
        // from a suitable media selection group.
        
        // Note that, when the current track is being played remotely via AirPlay, the language option
        // may not exactly match an option in your local asset's media selection. You may need to consider
        // an approximate comparison algorithm to determine the nearest match.
        
        // If you cannot find an exact or approximate match, you should return `nil` to ignore the
        // enable command.
        
        return nil
    }
    
    // Helper method to get the media selection group for disabling a language option`.
    
    private func disabledMediaSelection(for languageOption: MPNowPlayingInfoLanguageOption) -> AVMediaSelectionGroup? {
        
        // In your code, you would implement your logic for finding the media selection group
        // being disabled.
        
        // Note that, when the current track is being played remotely via AirPlay, the language option
        // may not exactly determine a media selection group in your local asset. You may need to consider
        // an approximate comparison algorithm to determine the nearest match.
        
        // If you cannot find an exact or approximate match, you should return `nil` to ignore the
        // disable command.
        
        return nil
    }
    
    // MARK: Remote Commands
    
    // Handle a command registered with the Remote Command Center.
    
    private func handleCommand(command: NowPlayableCommand, event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        
        switch command {
            
        case .pause:
            pause()
            
        case .play:
            play()
            
        case .stop:
            optOut()
            
        case .togglePausePlay:
            togglePlayPause()
            
        case .nextTrack:
            nextTrack()
            
        case .previousTrack:
            previousTrack()
            
        case .changePlaybackRate:
            guard let event = event as? MPChangePlaybackRateCommandEvent else { return .commandFailed }
            setPlaybackRate(event.playbackRate)
            
        case .seekBackward:
            guard let event = event as? MPSeekCommandEvent else { return .commandFailed }
            setPlaybackRate(event.type == .beginSeeking ? -3.0 : 1.0)
            
        case .seekForward:
            guard let event = event as? MPSeekCommandEvent else { return .commandFailed }
            setPlaybackRate(event.type == .beginSeeking ? 3.0 : 1.0)
            
        case .skipBackward:
            guard let event = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            skipBackward(by: event.interval)
            
        case .skipForward:
            guard let event = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            skipForward(by: event.interval)
            
        case .changePlaybackPosition:
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            seek(to: event.positionTime)
            
        case .enableLanguageOption:
            guard let event = event as? MPChangeLanguageOptionCommandEvent else { return .commandFailed }
            guard didEnableLanguageOption(event.languageOption) else { return .noActionableNowPlayingItem }

        case .disableLanguageOption:
            guard let event = event as? MPChangeLanguageOptionCommandEvent else { return .commandFailed }
            guard didDisableLanguageOption(event.languageOption) else { return .noActionableNowPlayingItem }

        default:
            break
        }
        
        return .success
    }
    
    // MARK: Interruptions
    
    // Handle a session interruption.
    
    private func handleInterrupt(with interruption: NowPlayableInterruption) {
        
        switch interruption {
            
        case .began:
            isInterrupted = true
            
        case .ended(let shouldPlay):
            isInterrupted = false
            
            switch playerState {
                
            case .stopped:
                break
                
            case .playing where shouldPlay:
                player.play()
                
            case .playing:
                playerState = .paused
                
            case .paused:
                break
            }
            
        case .failed(let error):
            print(error.localizedDescription)
            optOut()
        }
    }
    
}
