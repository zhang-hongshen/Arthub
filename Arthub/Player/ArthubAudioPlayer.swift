//
//  ArthubAudioPlayer.swift
//  Arthub
//
//  Created by 张鸿燊 on 7/2/2024.
//

import AVFoundation

struct Playlist {
    
    var items: [PlaylistItem] = []
    var currentIndex: Int?
    
    var currentItem: PlaylistItem? {
        guard let index = currentIndex, (0 ..< items.count).contains(index) else {
            return nil
        }
        return items[index]
    }
}

struct PlaylistItem {
    
    var url: URL
    var title: String
    var cover: URL?
    var artists: String
    var duration: TimeInterval
    
    init(url: URL, title: String = "", cover: URL? = nil,
         artists: String = "", duration: TimeInterval = 0) {
        self.url = url
        self.title = title
        self.cover = cover
        self.artists = artists
        self.duration = duration
    }
}

@Observable
class ArthubAudioPlayer: ObservableObject {
    
    public var isPlaying: Bool {
        return playerNode.isPlaying
    }
    public var currentTime: TimeInterval = 0
    
    public var currentIndex: Int? {
        return playlist.currentIndex
    }
    
    public var currentPlaylistItem: PlaylistItem? {
        return playlist.currentItem
    }
    
     private var currentAudioFile: AVAudioFile? = nil
    
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var playlist = Playlist()
    private var lastSeekTime: TimeInterval = 0
    private var lastPauseTime: TimeInterval = 0
    private var semaphore: DispatchSemaphore =  DispatchSemaphore(value: 1)
    private var timer: Timer? = nil
    
    init() {
        audioEngine.attach(playerNode)
    }
    
    func reset() {
        resetTimer()
        resetAudioProperty()
        resetPlayerNodeAndAudioEngine()
    }
    
    func resetTimer() {
        if let timer = timer {
            timer.invalidate()
            self.timer = nil
        }
    }
    
    func resetAudioProperty() {
        self.currentTime = 0
        self.lastSeekTime = 0
        self.lastPauseTime = 0
    }
    
    func resetPlayerNodeAndAudioEngine() {
        self.playerNode.stop()
        self.audioEngine.stop()
        self.audioEngine.reset()
    }
    
    func start(musicList: [Music], fromIndex: Int = 0) async throws {
        self.resetTimer()
        self.resetAudioProperty()
        var playlistItems : [PlaylistItem] = []
        for music in musicList {
            playlistItems.append(.init(
                url: music.url,
                title: music.title,
                cover: music.album?.cover,
                artists: music.getArtists().map{ $0.name }.joined(separator: " & "),
                duration: try await AVAsset(url: music.url).load(.duration).seconds
            ))
        }
        playlist.currentIndex = fromIndex
        playlist.items = playlistItems
        guard let currentPlaylistItem = currentPlaylistItem else {
            return
        }
        do {
            currentAudioFile = try AVAudioFile(forReading: currentPlaylistItem.url)
        } catch {
            self.continuePlay(fromIndex: playlist.currentIndex! + 1)
        }
                
        audioEngine.connect(playerNode,
                            to: audioEngine.outputNode,
                            format: currentAudioFile!.processingFormat)
        playerNode.scheduleFile(currentAudioFile!,
                                at: nil,
                                completionCallbackType: .dataPlayedBack) { _ in
            if 0 == self.lastSeekTime {
                self.continuePlay(fromIndex: self.playlist.currentIndex! + 1)
            }
        }
        try self.play()
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.currentTime = self.lastSeekTime +
            (self.playerNode.isPlaying ? self.playerNode.currentTime : self.lastPauseTime)
        }
    }
        
    func continuePlay(fromIndex proposedIndex: Int, offset: TimeInterval = 0) {
        
        semaphore.wait()
        defer { semaphore.signal() }
        
        self.resetTimer()
        self.resetAudioProperty()
        self.playlist.currentIndex = proposedIndex % playlist.items.count
        guard let currentPlaylistItem = self.currentPlaylistItem else {
            return
        }
        do {
            currentAudioFile = try AVAudioFile(forReading: currentPlaylistItem.url)
        } catch {
            self.continuePlay(fromIndex: proposedIndex + 1)
        }
        audioEngine.connect(playerNode,
                            to: audioEngine.outputNode,
                            format: currentAudioFile!.processingFormat)
        playerNode.scheduleFile(currentAudioFile!,
                                at: nil,
                                completionCallbackType: .dataPlayedBack) { _ in
            if 0 == self.lastSeekTime {
                self.continuePlay(fromIndex: self.playlist.currentIndex! + 1)
            }
        }
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.currentTime = self.lastSeekTime +
            (self.playerNode.isPlaying ? self.playerNode.currentTime : self.lastPauseTime)
        }
    }
    
    func seek(to time: TimeInterval) {
        semaphore.wait()
        defer { semaphore.signal() }
        
        guard let currentPlaylistItem = self.currentPlaylistItem,
              let playerTime = playerNode.playerTime else  {
            return
        }
        do {
            currentAudioFile = try AVAudioFile(forReading: currentPlaylistItem.url)
        } catch {
            self.continuePlay(fromIndex: playlist.currentIndex! + 1)
        }
        
        let startingFrame =
        AVAudioFramePosition(playerTime.sampleRate * time)
        let frameToPlay = AVAudioFrameCount(playerTime.sampleRate * (currentPlaylistItem.duration - time))
        if frameToPlay < 100 {
            return
        }
         
        self.lastSeekTime = time
        let lastSeekTime = self.lastSeekTime
        
        playerNode.stop()
        playerNode.prepare(withFrameCount: frameToPlay)
        playerNode.scheduleSegment(currentAudioFile!, startingFrame: startingFrame,
                                   frameCount: frameToPlay,
                                   at: nil, completionCallbackType: .dataPlayedBack) { _ in
            if lastSeekTime == self.lastSeekTime {
                self.continuePlay(fromIndex: self.playlist.currentIndex! + 1)
            }
        }
        playerNode.play()
    }
    
    func play() throws {
        if !audioEngine.isRunning {
            audioEngine.prepare()
            try audioEngine.start()
        }
        playerNode.play()
    }
    
    func pause() {
        self.lastPauseTime = self.playerNode.currentTime
        playerNode.pause()
    }
    
    func stop() {
        self.playerNode.stop()
        self.audioEngine.stop()
    }
    
    func setVolume(_ volume: Float) {
        playerNode.volume = volume.clamp(to: 0...1)
    }
    
}
