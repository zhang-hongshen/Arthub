//
//  LyricSegment.swift
//  Arthub
//
//  Created by 张鸿燊 on 2/2/2024.
//

import Foundation
import SwiftData

@Model
class LyricSegment {
    @Attribute(.unique) let id = UUID()
    
    var startedAt: TimeInterval
    var endedAt: TimeInterval
    var content:  String
    
    var music: Music? = nil
    
    init(startedAt: TimeInterval = 0, endedAt: TimeInterval = 0, 
         content: String = "") {
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.content = content
    }
}

extension LyricSegment: Hashable {
    static func == (lhs: LyricSegment, rhs: LyricSegment) -> Bool {
        return lhs.id == rhs.id
    }
}

extension LyricSegment {
    static public func examples() -> [LyricSegment] {
        return [
            LyricSegment(startedAt: 31, endedAt: 36, content: "只剩下鋼琴陪我談了一天"),
            LyricSegment(startedAt: 37, endedAt: 43, content: "睡著的大提琴 安靜的舊舊的"),
            LyricSegment(startedAt: 45, endedAt: 49, content: "我想你已表現的非常明白"),
            LyricSegment(startedAt: 50, endedAt: 57, content: "我懂我也知道 你沒有捨不得"),
            
            LyricSegment(startedAt: 58, endedAt: 63, content: "你說你也會難過 我不相信"),
            LyricSegment(startedAt: 64, endedAt: 70, content: "牽著你 陪著我 也只是曾經"),
            LyricSegment(startedAt: 71, endedAt: 76, content: "希望他是真的比我還要愛你"),
            LyricSegment(startedAt: 77, endedAt: 82, content: "我才會逼自己離開"),
            
            LyricSegment(startedAt: 83, endedAt: 91, content: "你要我說多難堪 我根本不想分開"),
            LyricSegment(startedAt: 92, endedAt: 97, content: "為什麼還要我用微笑來帶過"),
            LyricSegment(startedAt: 98, endedAt: 103, content: "我沒有這種天份 包容你也接受他"),
            LyricSegment(startedAt: 104, endedAt: 110, content: "不用擔心的太多 我會一直好好過"),
            
            LyricSegment(startedAt: 111, endedAt: 117, content: "你已經遠遠離開 我也會慢慢走開"),
            LyricSegment(startedAt: 118, endedAt: 122, content: "為什麼我連分開都遷就著你"),
            LyricSegment(startedAt: 123, endedAt: 129, content: "我真的沒有天份 安靜的沒這麼快"),
            LyricSegment(startedAt: 130, endedAt: 135, content: "我會學著放棄你 是因為我太愛你"),
            
            
            LyricSegment(startedAt: 151, endedAt: 156, content: "只剩下鋼琴陪我談了一天"),
            LyricSegment(startedAt: 157, endedAt: 163, content: "睡著的大提琴 安靜的舊舊的"),
            LyricSegment(startedAt: 164, endedAt: 170, content: "我想你已表現的非常明白"),
            LyricSegment(startedAt: 171, endedAt: 176, content: "我懂我也知道 你沒有捨不得"),
            
            LyricSegment(startedAt: 177, endedAt: 183, content: "你說你也會難過 我不相信"),
            LyricSegment(startedAt: 184, endedAt: 189, content: "牽著你 陪著我 也只是曾經"),
            LyricSegment(startedAt: 190, endedAt: 196, content: "希望他是真的比我還要愛你"),
            LyricSegment(startedAt: 197, endedAt: 201, content: "我才會逼自己離開"),
            LyricSegment(startedAt: 201.5, endedAt: 204, content: "ooh~"),
            
            LyricSegment(startedAt: 206, endedAt: 211, content: "你要我說多難堪 我根本不想分開"),
            LyricSegment(startedAt: 211.5, endedAt: 217, content: "為什麼還要我用微笑來帶過"),
            LyricSegment(startedAt: 218, endedAt: 224, content: "我沒有這種天份 包容你也接受他"),
            LyricSegment(startedAt: 225, endedAt: 230, content: "不用擔心的太多 我會一直好好過"),

            LyricSegment(startedAt: 231 , endedAt: 237, content: "你已經遠遠離開 我也會慢慢走開"),
            LyricSegment(startedAt: 238, endedAt: 243, content: "為什麼我連分開都遷就著你"),
            LyricSegment(startedAt: 244, endedAt: 250, content: "我真的沒有天份 安靜的沒這麼快"),
            LyricSegment(startedAt: 250.5, endedAt: 254, content: "我會學著放棄你"),
            LyricSegment(startedAt: 257.5, endedAt: 260, content: "是因為我太愛你"),
        ]
    }
}
