//
//  Lyric.swift
//  Arthub
//
//  Created by 张鸿燊 on 2/2/2024.
//

import Foundation

class Lyric: Identifiable {
    let id = UUID()
    var start: TimeInterval
    var end: TimeInterval
    var content:  String
    var phrases: [Lyric] = []
    
    init(start: TimeInterval = 0, end: TimeInterval = 0,
         content: String = "", phrases: [Lyric] = []) {
        self.start = start
        self.end = end
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
        return TTMLParser().parse(url: url)
    }
    
}

extension Lyric {
    static public func examples() -> [Lyric] {
        return [
            Lyric(start: 31, end: 36, content: "只剩下鋼琴陪我談了一天", phrases: [
                Lyric(start: 31, end: 31.5, content: "只"),
                Lyric(start: 31.5, end: 32.5, content: "剩下"),
                Lyric(start: 32.5, end: 33.5, content: "鋼琴"),
                Lyric(start: 33.5, end: 34.5, content: "陪我"),
                Lyric(start: 34.5, end: 35, content: "談了"),
                Lyric(start: 35, end: 36, content: "一天"),
            ]),
            Lyric(start: 37, end: 43, content: "睡著的大提琴 安靜的舊舊的"),
            Lyric(start: 45, end: 49, content: "我想你已表現的非常明白"),
            Lyric(start: 50, end: 57, content: "我懂我也知道 你沒有捨不得"),
            
            Lyric(start: 58, end: 63, content: "你說你也會難過 我不相信"),
            Lyric(start: 64, end: 70, content: "牽著你 陪著我 也只是曾經"),
            Lyric(start: 71, end: 76, content: "希望他是真的比我還要愛你"),
            Lyric(start: 77, end: 82, content: "我才會逼自己離開"),
            
            Lyric(start: 83, end: 91, content: "你要我說多難堪 我根本不想分開"),
            Lyric(start: 92, end: 97, content: "為什麼還要我用微笑來帶過"),
            Lyric(start: 98, end: 103, content: "我沒有這種天份 包容你也接受他"),
            Lyric(start: 104, end: 110, content: "不用擔心的太多 我會一直好好過"),
            
            Lyric(start: 111, end: 117, content: "你已經遠遠離開 我也會慢慢走開"),
            Lyric(start: 118, end: 122, content: "為什麼我連分開都遷就著你"),
            Lyric(start: 123, end: 129, content: "我真的沒有天份 安靜的沒這麼快"),
            Lyric(start: 130, end: 135, content: "我會學著放棄你 是因為我太愛你"),
            
            
            Lyric(start: 151, end: 156, content: "只剩下鋼琴陪我談了一天"),
            Lyric(start: 157, end: 163, content: "睡著的大提琴 安靜的舊舊的"),
            Lyric(start: 164, end: 170, content: "我想你已表現的非常明白"),
            Lyric(start: 171, end: 176, content: "我懂我也知道 你沒有捨不得"),
            
            Lyric(start: 177, end: 183, content: "你說你也會難過 我不相信"),
            Lyric(start: 184, end: 189, content: "牽著你 陪著我 也只是曾經"),
            Lyric(start: 190, end: 196, content: "希望他是真的比我還要愛你"),
            Lyric(start: 197, end: 201, content: "我才會逼自己離開"),
            Lyric(start: 201.5, end: 204, content: "ooh~"),
            
            Lyric(start: 206, end: 211, content: "你要我說多難堪 我根本不想分開"),
            Lyric(start: 211.5, end: 217, content: "為什麼還要我用微笑來帶過"),
            Lyric(start: 218, end: 224, content: "我沒有這種天份 包容你也接受他"),
            Lyric(start: 225, end: 230, content: "不用擔心的太多 我會一直好好過"),

            Lyric(start: 231 , end: 237, content: "你已經遠遠離開 我也會慢慢走開"),
            Lyric(start: 238, end: 243, content: "為什麼我連分開都遷就著你"),
            Lyric(start: 244, end: 250, content: "我真的沒有天份 安靜的沒這麼快"),
            Lyric(start: 250.5, end: 254, content: "我會學著放棄你"),
            Lyric(start: 257.5, end: 260, content: "是因為我太愛你"),
        ]
    }
}
