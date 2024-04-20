//
//  ArthubVideoPlayer.swift
//  Arthub
//
//  Created by 张鸿燊 on 4/2/2024.
//

import AVFoundation
import MediaPlayer

@Observable class ArthubVideoPlayer: ArthubPlayer {
    
    var aspectRatio: CGFloat {
        guard let videoSize = currentVideoSize else { return 1 }
        return videoSize.width / videoSize.height
    }
    
    var duration: TimeInterval {
        guard let item = player.currentItem else { return 0 }
        return switch item.asset.status(of: .duration) {
        case.loaded(let duration): duration.seconds
        default: 0
        }
    }
    
    var currentItemID: Int? {
        guard let currentIndex else { return nil }
        return staticMetadatas[currentIndex].id.intValue
    }
    
    private(set) var currentTime: TimeInterval = 0
    
    private(set) var currentIndex: Int? = nil
    
    private(set) var videoSizeOptions: [CGSize] = []
    
    private(set) var currentVideoSize: CGSize? = nil
    
    // The app-supplied object that provides `NowPlayable`-conformant behavior.
    
    private let nowPlayableBehavior: NowPlayable
    
    // A playlist of items to play.
    
    private var playerItems: [AVPlayerItem] = []
    
    private var videoComposition =  AVMutableVideoComposition()
    
    // Metadata for each item.
    
    private var staticMetadatas: [NowPlayableStaticMetadata] = []
    
    // The internal state of this AssetPlayer separate from the state
    // of its AVQueuePlayer.
    
    // `true` if the current session has been interrupted by another app.
    
    private var isInterrupted: Bool = false
    
    // Private observers of notifications and property changes.
    
    private var itemObserver: NSKeyValueObservation!
    private var rateObserver: NSKeyValueObservation!
    private var statusObserver: NSKeyValueObservation!
    private var tracksObserver: NSKeyValueObservation!
    private var currentTimeObserver: Any? = nil
    
    private var itemDidPlayToEndTimeObserver: NSObjectProtocol!
    
    override init() {
        self.nowPlayableBehavior = VideoNowPlayableBehavior()
        super.init()
        player.allowsExternalPlayback = true
    }
    
    func preloadItems(playableAssets: [NowPlayableStaticMetadata]) {
        self.staticMetadatas = playableAssets
        self.playerItems = playableAssets.map {
            AVPlayerItem(asset: AVAsset(url: $0.assetURL),
                         automaticallyLoadedAssetKeys: [
                            .availableMediaCharacteristicsWithMediaSelectionOptions,
                            .duration,
                            .tracks,
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
    
    func start(from index: Int = 0, at: TimeInterval = 0) async throws {
        
        
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
        tracksObserver = player.observe(\.currentItem?.tracks, options: .new) {
            [unowned self] _, b in
            print("currentItem tracks is loaded, oldValue \(b.oldValue??.count ?? 0), newValue \(b.newValue??.count ?? 0)")
            setVideoComposition()
        }
        
        // Invoke callback every half second
        let interval = CMTime(seconds: 0.5,
                              preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        // Add time observer. Invoke closure on the main queue.
        currentTimeObserver =
        player.addPeriodicTimeObserver(forInterval: interval,
                                       queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
        }
        
        NotificationCenter.default.addObserver(
            forName: AVPlayer.eligibleForHDRPlaybackDidChangeNotification,
            object: player,
            queue: .main) { notification in
                print("eligibleForHDRPlayback Changed")
                self.handleEligibleForHDRPlaybackChange()
            }
    }
    
    func deregisterObserver() {
        itemObserver = nil
        rateObserver = nil
        statusObserver = nil
        tracksObserver = nil
        itemDidPlayToEndTimeObserver = nil
        if let observer = currentTimeObserver {
            player.removeTimeObserver(observer)
            currentTimeObserver = nil
        }
    }
    
    // Stop the playback session.
    
    func optOut() {
        deregisterObserver()
        
        player.pause()
        playerState = .stopped
        currentTime = 0
        videoSizeOptions = []
        currentVideoSize = nil
        
        nowPlayableBehavior.handleNowPlayableSessionEnd()
        
    }
    
    private func handleEligibleForHDRPlaybackChange() {
        setVideoCompositionColorProperties()
//        guard let item = player.currentItem else { return }
//        item.videoComposition = self.videoComposition.copy() as? AVVideoComposition
    }
    
    private func setVideoCompositionColorProperties() {
        if AVPlayer.eligibleForHDRPlayback {
            videoComposition.colorPrimaries = AVVideoColorPrimaries_ITU_R_2020
            videoComposition.colorTransferFunction = AVVideoTransferFunction_ITU_R_2100_HLG
            videoComposition.colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_2020
        } else {
            videoComposition.colorPrimaries = AVVideoColorPrimaries_ITU_R_709_2
            videoComposition.colorTransferFunction = AVVideoTransferFunction_ITU_R_709_2
            videoComposition.colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_709_2
        }
    }
    
    private func setVideoComposition() {
        guard let item = player.currentItem else { return }
        Task.detached {
            let tracks = item.tracks.compactMap { $0.assetTrack }.filter({ $0.mediaType == .video })
            for track in tracks {
                let (naturalSize, preferredTransform) = try await track.load(.naturalSize, .preferredTransform)
                let videoSize = naturalSize.applying(preferredTransform)
                self.currentVideoSize = videoSize
                self.videoSizeOptions.append(videoSize)
            }
        }
    }
    
    func generateImage(for time: TimeInterval,
                       completionHanlder: @escaping (CGImage) -> Void) {
        guard let item = player.currentItem else { return }
        
        AVAssetImageGenerator(asset: item.asset)
            .generateCGImageAsynchronously(for:
                    .init(seconds: time,
                          preferredTimescale: 1)) { image, time, err in
                if let err = err {
                    print("Generate preview Image error, \(err)")
                    return
                }
                guard let image = image else {
                    print("No image")
                    return
                }
                completionHanlder(image)
        }
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
                    for option in mediaSelectionGroup.options {
                        print("\(mediaCharacteristic.hashValue)  Option: \(option.displayName)")
                    }
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
        
        guard let nextIndex else { return }
        
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
            guard let currentIndex else { return nil }
            switch playerMode {
            case .noRepeat:
                guard currentIndex - 1 >= 0 else {
                    return nil
                }
                return currentIndex - 1
            case .repeatPlaylist:
                return (currentIndex -  1 + playerItems.count) % playerItems.count
            case .repeatItem:
                return currentIndex
            }
        }
        
        guard let previousIndex else { return }
        
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
                print("Video Finished")
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
    
    func skipForward(by interval: TimeInterval) {
        seek(to: player.currentTime() + CMTime(seconds: interval, preferredTimescale: 1))
    }
    
    func skipBackward(by interval: TimeInterval) {
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
