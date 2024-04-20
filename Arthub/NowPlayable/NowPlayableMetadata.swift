//
//  NowPlayableStaticMetadata.swift
//  Arthub
//
//  Created by 张鸿燊 on 21/2/2024.
//

import Foundation
import MediaPlayer

struct NowPlayableStaticMetadata {
    
    let id: NSNumber                    // MPMediaItemPropertyPersistentID
    let assetURL: URL                   // MPNowPlayingInfoPropertyAssetURL
    let mediaType: MPNowPlayingInfoMediaType
                                        // MPNowPlayingInfoPropertyMediaType
    let isLiveStream: Bool              // MPNowPlayingInfoPropertyIsLiveStream
    
    let title: String                   // MPMediaItemPropertyTitle
    let artist: String?                 // MPMediaItemPropertyArtist
    let artwork: MPMediaItemArtwork?    // MPMediaItemPropertyArtwork
    
    let albumArtist: String?            // MPMediaItemPropertyAlbumArtist
    let albumTitle: String?             // MPMediaItemPropertyAlbumTitle
    
    init(id: NSNumber, assetURL: URL, mediaType: MPNowPlayingInfoMediaType, isLiveStream: Bool,
         title: String, artist: String? = nil, artwork: MPMediaItemArtwork? = nil,
         albumArtist: String? = nil, albumTitle: String? = nil) {
        self.id = id
        self.assetURL = assetURL
        self.mediaType = mediaType
        self.isLiveStream = isLiveStream
        self.title = title
        self.artist = artist
        self.artwork = artwork
        self.albumArtist = albumArtist
        self.albumTitle = albumTitle
    }
    
}

struct NowPlayableDynamicMetadata {
    
    let rate: Float                     // MPNowPlayingInfoPropertyPlaybackRate
    let position: Float                 // MPNowPlayingInfoPropertyElapsedPlaybackTime
    let duration: Float                 // MPMediaItemPropertyPlaybackDuration
    
    let currentLanguageOptions: [MPNowPlayingInfoLanguageOption]
                                        // MPNowPlayingInfoPropertyCurrentLanguageOptions
    let availableLanguageOptionGroups: [MPNowPlayingInfoLanguageOptionGroup]
                                        // MPNowPlayingInfoPropertyAvailableLanguageOptions
    
}
