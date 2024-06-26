//
//  NowPlayableBehavior.swift
//  Arthub
//
//  Created by 张鸿燊 on 21/2/2024.
//

import Foundation
import MediaPlayer

class NowPlayableBehavior: NowPlayable {
    
    var defaultAllowsExternalPlayback: Bool { return true }
    
    var defaultRegisteredCommands: [NowPlayableCommand] {
        return [.togglePausePlay,
                .play,
                .pause,
                .nextTrack,
                .previousTrack,
                .skipBackward,
                .skipForward,
                .changePlaybackPosition,
                .changePlaybackRate,
                .enableLanguageOption,
                .disableLanguageOption
        ]
    }
    
    var defaultDisabledCommands: [NowPlayableCommand] {
        
        // By default, no commands are disabled.
        
        return []
    }
    
    #if !os(macOS)
    // The observer of audio session interruption notifications.
    
    private var interruptionObserver: NSObjectProtocol!
    
    // The handler to be invoked when an interruption begins or ends.
    
    private var interruptionHandler: (NowPlayableInterruption) -> Void = { _ in }
    #endif
    
    func handleNowPlayableConfiguration(commands: [NowPlayableCommand],
                                        disabledCommands: [NowPlayableCommand],
                                        commandHandler: @escaping (NowPlayableCommand, MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus,
                                        interruptionHandler: @escaping (NowPlayableInterruption) -> Void) {
        #if !os(macOS)
        // Remember the interruption handler.
        
        self.interruptionHandler = interruptionHandler
        #endif
        // Use the default behavior for registering commands.
        
        configureRemoteCommands(commands, disabledCommands: disabledCommands, commandHandler: commandHandler)
    }
    
    func handleNowPlayableSessionStart() throws {
        
        #if os(macOS)
        // Set the playback state.
        MPNowPlayingInfoCenter.default().playbackState = .paused
        #else
        let audioSession = AVAudioSession.sharedInstance()
        
        // Observe interruptions to the audio session.
        
        interruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification,
                                                                      object: audioSession,
                                                                      queue: .main) {
            [unowned self] notification in
            self.handleAudioSessionInterruption(notification: notification)
        }
         
        try audioSession.setCategory(.playback, mode: .default)
        
         // Make the audio session active.
        
        try audioSession.setActive(true)
        #endif
    }
    
    func handleNowPlayableSessionEnd() {
        #if os(macOS)
        // Set the playback state.
        
        MPNowPlayingInfoCenter.default().playbackState = .stopped
        #else
        // Stop observing interruptions to the audio session.
        
        interruptionObserver = nil
        
        // Make the audio session inactive.
        
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Failed to deactivate audio session, error: \(error)")
        }
        #endif
    }
    
    func handleNowPlayableItemChange(metadata: NowPlayableStaticMetadata) {
        
        // Use the default behavior for setting player item metadata.
        
        setNowPlayingMetadata(metadata)
    }
    
    func handleNowPlayablePlaybackChange(playing isPlaying: Bool, metadata: NowPlayableDynamicMetadata) {
        
        // Start with the default behavior for setting playback information.
        
        setNowPlayingPlaybackInfo(metadata)
        
        #if os(macOS)
        // Then set the playback state, too.
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
        #endif
    }
    
    #if !os(macOS)
    // Helper method to handle an audio session interruption notification.
    
    private func handleAudioSessionInterruption(notification: Notification) {
        
        // Retrieve the interruption type from the notification.
        
        guard let userInfo = notification.userInfo,
            let interruptionTypeUInt = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let interruptionType = AVAudioSession.InterruptionType(rawValue: interruptionTypeUInt) else { return }
        
        // Begin or end an interruption.
        
        switch interruptionType {
            
        case .began:
            
            // When an interruption begins, just invoke the handler.
            
            interruptionHandler(.began)
            
        case .ended:
            
            // When an interruption ends, determine whether playback should resume
            // automatically, and reactivate the audio session if necessary.
            
            do {
                
                try AVAudioSession.sharedInstance().setActive(true)
                
                var shouldResume = false
                
                if let optionsUInt = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt,
                    AVAudioSession.InterruptionOptions(rawValue: optionsUInt).contains(.shouldResume) {
                    shouldResume = true
                }
                
                interruptionHandler(.ended(shouldResume))
            }
            
            // When the audio session cannot be resumed after an interruption,
            // invoke the handler with error information.
                
            catch {
                interruptionHandler(.failed(error))
            }
            
        @unknown default:
            break
        }
    }
    #endif
    
}
