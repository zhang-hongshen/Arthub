//
//  ArthubAudioPlayer.swift
//  Arthub
//
//  Created by 张鸿燊 on 22/2/2024.
//

import AVFoundation
import MediaPlayer

@Observable 
class ArthubAudioPlayer: ArthubPlayer {

    var shuffled: Bool = false
    
    var currentItemID: Int? {
        guard let currentIndex else { return nil }
        return staticMetadatas[currentIndex].id.intValue
    }
    
    var duration: TimeInterval {
        guard let item = player.currentItem else { return 0 }
        return switch item.asset.status(of: .duration) {
        case.loaded(let duration): duration.seconds
        default: 0
        }
    }
    
    var isPlaylistEmpty: Bool {
        return playerItems.isEmpty
    }
    
    private(set) var currentTime: TimeInterval = 0
    
    private(set) var currentIndex: Int? = nil
    
    // The app-supplied object that provides `NowPlayable`-conformant behavior.
    
    private let nowPlayableBehavior: NowPlayable
    
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
    
    private var itemDidPlayToEndTimeObserver: NSObjectProtocol!
    
    override init() {
        self.nowPlayableBehavior = AudioNowPlayableBehavior()

        super.init()
        player.allowsExternalPlayback = true
        
        // Construct lists of commands to be registered or disabled.
    }
    
    func preloadItems(playableAssets: [NowPlayableStaticMetadata]) {
        self.staticMetadatas = playableAssets
        self.playerItems = playableAssets.map {
            AVPlayerItem(asset: AVAsset(url: $0.assetURL),
                         automaticallyLoadedAssetKeys: [
                            .availableMediaCharacteristicsWithMediaSelectionOptions,
                            .duration
                         ])
        }
        // Configure the app for Now Playing Info and Remote Command Center behaviors.
        var registeredCommands : [NowPlayableCommand] = []
        var enabledCommands : [NowPlayableCommand] = []
        for group in nowPlayableBehavior.defaultCommandCollections {
            registeredCommands.append(contentsOf: group.commands.compactMap { $0.shouldRegister ? $0.command : nil })
            enabledCommands.append(contentsOf: group.commands.compactMap { $0.shouldDisable ? $0.command : nil })
        }
        
        nowPlayableBehavior.handleNowPlayableConfiguration(commands: registeredCommands,
                                                               disabledCommands: enabledCommands,
                                                               commandHandler: handleCommand(command:event:),
                                                               interruptionHandler: handleInterrupt(with:))
    }
    
    func start(from index: Int = 0, at: TimeInterval = 0) throws {
        
        if !playerItems.indices.contains(index) {
            return
        }
        
        // Start a playback session.
        try nowPlayableBehavior.handleNowPlayableSessionStart()
        
        // Start playing, if there is something to play.
        replaceCurrentItem(with: playerItems[index], at: .init(seconds: at, preferredTimescale: 1))
        currentIndex = index
        
        registerObserver()
        
        play()
    }
    
    
    func registerObserver() {
        
        // Observe changes to the current item and playback rate.
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
        
        // sync player currentTime
        player.addPeriodicTimeObserver(forInterval:
                .init(seconds: 1, preferredTimescale: 1),
                                       queue: .main) { time in
            self.currentTime = time.seconds
        }
    }
    
    func deregisterObserver() {
        itemObserver = nil
        rateObserver = nil
        statusObserver = nil
        itemDidPlayToEndTimeObserver = nil
    }
    
    // Stop the playback session.
    
    func optOut() {
        
        deregisterObserver()
        
        player.pause()
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
        case .failed(_):
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
    
    func toggleShuffle() {
        shuffled.toggle()
    }
    
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
        
        var nextIndex: Int? {
            guard let currentIndex else { return nil }
            if shuffled {
                return playerItems.firstIndex(where: { $0 == playerItems.randomElement() })
            }
            switch playerMode {
            case .noRepeat:
                guard currentIndex + 1 < playerItems.count else {
                    return nil
                }
                return currentIndex + 1
            case .repeatPlaylist:
                return (currentIndex + 1) % playerItems.count
            case .repeatItem:
                return currentIndex
            }
        }
        
        guard let nextIndex else {
            replaceCurrentItem(with: nil)
            return
        }
        
        replaceCurrentItem(with: playerItems[nextIndex])
        currentIndex = nextIndex
        if case .playing = playerState {
            player.play()
        }
    }
    
    func previousTrack() {
        
        if case .stopped = playerState { return }
        
        guard player.currentTime().seconds < 3 else { seek(to: .zero); return }

        var previousIndex: Int? {
            guard let currentIndex = currentIndex else {
                return nil
            }
            switch playerMode {
            case .noRepeat:
                guard currentIndex >= 1 else {
                    return nil
                }
                return currentIndex - 1
            case .repeatPlaylist:
                return (currentIndex -  1 + playerItems.count) % playerItems.count
            case .repeatItem:
                return currentIndex
            }
        }
        
        guard let previousIndex else {
            replaceCurrentItem(with: nil)
            return
        }
        
        replaceCurrentItem(with: playerItems[previousIndex])
        
        currentIndex = previousIndex
        
        if case .playing = playerState {
            player.play()
        }
    }
    
    
    private func replaceCurrentItem(with item: AVPlayerItem?, at: CMTime = .zero) {
        if item != player.currentItem {
            player.replaceCurrentItem(with: item)
        }
        currentTime = at.seconds
        seek(to: at)
        itemDidPlayToEndTimeObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: player.currentItem,
            queue: .main) { notification in
                print("Audio Finished")
                self.nextTrack()
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
