//
//  Lyric.swift
//  Arthub
//
//  Created by 张鸿燊 on 2/2/2024.
//

import Foundation

class Lyric: Identifiable {
    let id = UUID()
    
    var startedAt: TimeInterval
    var endedAt: TimeInterval
    var content:  String
    var phrases: [Lyric] = []
    
    var music: Music?
    
    init(startedAt: TimeInterval = 0, endedAt: TimeInterval = 0,
         content: String = "", phrases: [Lyric] = []) {
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.content = content
        self.phrases = phrases
    }
}

extension Lyric: Equatable {
    
    static func == (lhs: Lyric, rhs: Lyric) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Lyric {
    
    static func loadLyrics(url: URL) -> [Lyric] {
        return TTMLParser.shared.parse(url: url)
    }
    
}

extension Lyric {
    static public func examples() -> [Lyric] {
        return [
            Lyric(startedAt: 31, endedAt: 36, content: "只剩下鋼琴陪我談了一天", phrases: [
                Lyric(startedAt: 31, endedAt: 31.5, content: "只"),
                Lyric(startedAt: 31.5, endedAt: 32.5, content: "剩下"),
                Lyric(startedAt: 32.5, endedAt: 33.5, content: "鋼琴"),
                Lyric(startedAt: 33.5, endedAt: 34.5, content: "陪我"),
                Lyric(startedAt: 34.5, endedAt: 35, content: "談了"),
                Lyric(startedAt: 35, endedAt: 36, content: "一天"),
            ]),
            Lyric(startedAt: 37, endedAt: 43, content: "睡著的大提琴 安靜的舊舊的"),
            Lyric(startedAt: 45, endedAt: 49, content: "我想你已表現的非常明白"),
            Lyric(startedAt: 50, endedAt: 57, content: "我懂我也知道 你沒有捨不得"),
            
            Lyric(startedAt: 58, endedAt: 63, content: "你說你也會難過 我不相信"),
            Lyric(startedAt: 64, endedAt: 70, content: "牽著你 陪著我 也只是曾經"),
            Lyric(startedAt: 71, endedAt: 76, content: "希望他是真的比我還要愛你"),
            Lyric(startedAt: 77, endedAt: 82, content: "我才會逼自己離開"),
            
            Lyric(startedAt: 83, endedAt: 91, content: "你要我說多難堪 我根本不想分開"),
            Lyric(startedAt: 92, endedAt: 97, content: "為什麼還要我用微笑來帶過"),
            Lyric(startedAt: 98, endedAt: 103, content: "我沒有這種天份 包容你也接受他"),
            Lyric(startedAt: 104, endedAt: 110, content: "不用擔心的太多 我會一直好好過"),
            
            Lyric(startedAt: 111, endedAt: 117, content: "你已經遠遠離開 我也會慢慢走開"),
            Lyric(startedAt: 118, endedAt: 122, content: "為什麼我連分開都遷就著你"),
            Lyric(startedAt: 123, endedAt: 129, content: "我真的沒有天份 安靜的沒這麼快"),
            Lyric(startedAt: 130, endedAt: 135, content: "我會學著放棄你 是因為我太愛你"),
            
            
            Lyric(startedAt: 151, endedAt: 156, content: "只剩下鋼琴陪我談了一天"),
            Lyric(startedAt: 157, endedAt: 163, content: "睡著的大提琴 安靜的舊舊的"),
            Lyric(startedAt: 164, endedAt: 170, content: "我想你已表現的非常明白"),
            Lyric(startedAt: 171, endedAt: 176, content: "我懂我也知道 你沒有捨不得"),
            
            Lyric(startedAt: 177, endedAt: 183, content: "你說你也會難過 我不相信"),
            Lyric(startedAt: 184, endedAt: 189, content: "牽著你 陪著我 也只是曾經"),
            Lyric(startedAt: 190, endedAt: 196, content: "希望他是真的比我還要愛你"),
            Lyric(startedAt: 197, endedAt: 201, content: "我才會逼自己離開"),
            Lyric(startedAt: 201.5, endedAt: 204, content: "ooh~"),
            
            Lyric(startedAt: 206, endedAt: 211, content: "你要我說多難堪 我根本不想分開"),
            Lyric(startedAt: 211.5, endedAt: 217, content: "為什麼還要我用微笑來帶過"),
            Lyric(startedAt: 218, endedAt: 224, content: "我沒有這種天份 包容你也接受他"),
            Lyric(startedAt: 225, endedAt: 230, content: "不用擔心的太多 我會一直好好過"),

            Lyric(startedAt: 231 , endedAt: 237, content: "你已經遠遠離開 我也會慢慢走開"),
            Lyric(startedAt: 238, endedAt: 243, content: "為什麼我連分開都遷就著你"),
            Lyric(startedAt: 244, endedAt: 250, content: "我真的沒有天份 安靜的沒這麼快"),
            Lyric(startedAt: 250.5, endedAt: 254, content: "我會學著放棄你"),
            Lyric(startedAt: 257.5, endedAt: 260, content: "是因為我太愛你"),
        ]
    }
}
