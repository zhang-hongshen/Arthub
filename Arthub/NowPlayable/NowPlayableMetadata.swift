//
//  NowPlayableStaticMetadata.swift
//  Arthub
//
//  Created by 张鸿燊 on 21/2/2024.
//

import Foundation
import MediaPlayer

struct NowPlayableStaticMetadata {
    
    let assetURL: URL                   // MPNowPlayingInfoPropertyAssetURL
    let mediaType: MPNowPlayingInfoMediaType
                                        // MPNowPlayingInfoPropertyMediaType
    let isLiveStream: Bool              // MPNowPlayingInfoPropertyIsLiveStream
    
    let title: String                   // MPMediaItemPropertyTitle
    let artist: String?                 // MPMediaItemPropertyArtist
    let artwork: MPMediaItemArtwork?    // MPMediaItemPropertyArtwork
    
    let albumArtist: String?            // MPMediaItemPropertyAlbumArtist
    let albumTitle: String?             // MPMediaItemPropertyAlbumTitle
    
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
