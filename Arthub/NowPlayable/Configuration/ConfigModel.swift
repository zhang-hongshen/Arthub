/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
`ConfigModel` is the data model containing the configuration to use for playback.
*/

import Foundation
import MediaPlayer
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct ConfigModel {
    
    static var shared: ConfigModel!
    
    // The platform-specific customization of the NowPlayable protocol.
    
    let nowPlayableBehavior: NowPlayable
    
    // The data model describing the configuration to use for playback.
    
    var allowsExternalPlayback: Bool
    var assets: [ConfigAsset] = []
    var commandCollections: [ConfigCommandCollection] = []
    
    // Initialize a new configuration data model.
    
    init(nowPlayableBehavior: NowPlayable) {
        
        guard ConfigModel.shared == nil else { fatalError("ConfigModel must be a singleton") }
        
        self.nowPlayableBehavior = nowPlayableBehavior
        self.allowsExternalPlayback = nowPlayableBehavior.defaultAllowsExternalPlayback
        self.commandCollections = defaultCommandCollections
        
        ConfigModel.shared = self
    }
    
    mutating func setAssets(_ assets: [ConfigAsset]) {
        self.assets = assets
    }
}

extension ConfigModel {
    
    // Create the command collections, and enable a default set of commands.
    
    fileprivate var defaultCommandCollections: [ConfigCommandCollection] {
        
        // Arrange the commands into collections.
        
        let collection1 = [ConfigCommand(.pause, "Pause"),
                           ConfigCommand(.play, "Play"),
                           ConfigCommand(.stop, "Stop"),
                           ConfigCommand(.togglePausePlay, "Play/Pause")]
        let collection2 = [ConfigCommand(.nextTrack, "Next Track"),
                           ConfigCommand(.previousTrack, "Previous Track"),
                           ConfigCommand(.changeRepeatMode, "Repeat Mode"),
                           ConfigCommand(.changeShuffleMode, "Shuffle Mode")]
        let collection3 = [ConfigCommand(.changePlaybackRate, "Playback Rate"),
                           ConfigCommand(.seekBackward, "Seek Backward"),
                           ConfigCommand(.seekForward, "Seek Forward"),
                           ConfigCommand(.skipBackward, "Skip Backward"),
                           ConfigCommand(.skipForward, "Skip Forward"),
                           ConfigCommand(.changePlaybackPosition, "Playback Position")]
        let collection4 = [ConfigCommand(.rating, "Rating"),
                           ConfigCommand(.like, "Like"),
                           ConfigCommand(.dislike, "Dislike")]
        let collection5 = [ConfigCommand(.bookmark, "Bookmark")]
        let collection6 = [ConfigCommand(.enableLanguageOption, "Enable Language Option"),
                           ConfigCommand(.disableLanguageOption, "Disable Language Option")]
        
        // Create the collections.
        
        let registeredCommands = nowPlayableBehavior.defaultRegisteredCommands
        let disabledCommands = nowPlayableBehavior.defaultDisabledCommands
        
        let commandCollections = [
            ConfigCommandCollection("Playback", commands: collection1, registered: registeredCommands, disabled: disabledCommands),
            ConfigCommandCollection("Navigating Between Tracks", commands: collection2, registered: registeredCommands, disabled: disabledCommands),
            ConfigCommandCollection("Navigating Track Contents", commands: collection3, registered: registeredCommands, disabled: disabledCommands),
            ConfigCommandCollection("Rating Media Items", commands: collection4, registered: registeredCommands, disabled: disabledCommands),
            ConfigCommandCollection("Bookmarking Media Items", commands: collection5, registered: registeredCommands, disabled: disabledCommands),
            ConfigCommandCollection("Enabling Language Options", commands: collection6, registered: registeredCommands, disabled: disabledCommands)
        ]
        
        return commandCollections
    }
    
    // Create artwork.
    
    private func artworkNamed(_ imageName: String) -> MPMediaItemArtwork {
        
        #if os(macOS)
        let image = NSImage(named: imageName)!
        #else
        let image = UIImage(named: imageName)!
        #endif
        
        return MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }
    
}

