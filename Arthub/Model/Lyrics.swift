//
//  Lyrics.swift
//  Arthub
//
//  Created by 张鸿燊 on 2/2/2024.
//

import Foundation


struct LyricSegment: Identifiable{
    let id = UUID()
    var startedAt: TimeInterval?
    var endedAt: TimeInterval?
    var text:  String
    
    init(startedAt: TimeInterval? = nil, endedAt: TimeInterval? = nil, text: String = "") {
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.text = text
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
            LyricSegment(startedAt: 31, endedAt: 36, text: "只剩下鋼琴陪我談了一天"),
            LyricSegment(startedAt: 37, endedAt: 43, text: "睡著的大提琴 安靜的舊舊的"),
            LyricSegment(startedAt: 45, endedAt: 49, text: "我想你已表現的非常明白"),
            LyricSegment(startedAt: 50, endedAt: 57, text: "我懂我也知道 你沒有捨不得"),
            
            LyricSegment(startedAt: 58, endedAt: 63, text: "你說你也會難過 我不相信"),
            LyricSegment(startedAt: 64, endedAt: 70, text: "牽著你 陪著我 也只是曾經"),
            LyricSegment(startedAt: 71, endedAt: 76, text: "希望他是真的比我還要愛你"),
            LyricSegment(startedAt: 77, endedAt: 82, text: "我才會逼自己離開"),
            
            LyricSegment(startedAt: 83, endedAt: 91, text: "你要我說多難堪 我根本不想分開"),
            LyricSegment(startedAt: 92, endedAt: 97, text: "為什麼還要我用微笑來帶過"),
            LyricSegment(startedAt: 98, endedAt: 103, text: "我沒有這種天份 包容你也接受他"),
            LyricSegment(startedAt: 104, endedAt: 110, text: "不用擔心的太多 我會一直好好過"),
            
            LyricSegment(startedAt: 111, endedAt: 117, text: "你已經遠遠離開 我也會慢慢走開"),
            LyricSegment(startedAt: 118, endedAt: 122, text: "為什麼我連分開都遷就著你"),
            LyricSegment(startedAt: 123, endedAt: 129, text: "我真的沒有天份 安靜的沒這麼快"),
            LyricSegment(startedAt: 130, endedAt: 135, text: "我會學著放棄你 是因為我太愛你"),
            
            
            LyricSegment(startedAt: 151, endedAt: 156, text: "只剩下鋼琴陪我談了一天"),
            LyricSegment(startedAt: 157, endedAt: 163, text: "睡著的大提琴 安靜的舊舊的"),
            LyricSegment(startedAt: 164, endedAt: 170, text: "我想你已表現的非常明白"),
            LyricSegment(startedAt: 171, endedAt: 176, text: "我懂我也知道 你沒有捨不得"),
            
            LyricSegment(startedAt: 177, endedAt: 183, text: "你說你也會難過 我不相信"),
            LyricSegment(startedAt: 184, endedAt: 189, text: "牽著你 陪著我 也只是曾經"),
            LyricSegment(startedAt: 190, endedAt: 196, text: "希望他是真的比我還要愛你"),
            LyricSegment(startedAt: 197, endedAt: 201, text: "我才會逼自己離開"),
            LyricSegment(startedAt: 201.5, endedAt: 204, text: "ooh~"),
            
            LyricSegment(startedAt: 206, endedAt: 211, text: "你要我說多難堪 我根本不想分開"),
            LyricSegment(startedAt: 211.5, endedAt: 217, text: "為什麼還要我用微笑來帶過"),
            LyricSegment(startedAt: 218, endedAt: 224, text: "我沒有這種天份 包容你也接受他"),
            LyricSegment(startedAt: 225, endedAt: 230, text: "不用擔心的太多 我會一直好好過"),

            LyricSegment(startedAt: 231 , endedAt: 237, text: "你已經遠遠離開 我也會慢慢走開"),
            LyricSegment(startedAt: 238, endedAt: 243, text: "為什麼我連分開都遷就著你"),
            LyricSegment(startedAt: 244, endedAt: 250, text: "我真的沒有天份 安靜的沒這麼快"),
            LyricSegment(startedAt: 250.5, endedAt: 254, text: "我會學著放棄你"),
            LyricSegment(startedAt: 257.5, endedAt: 260, text: "是因為我太愛你"),
        ]
    }
}

class Lyrics {
    var content: String
    let regex = /(?<startedAt>(\d{2}:)?(\d{2}:\d{2})(.\d{2})?)\s+(?<endedAt>(\d{2}:)?(\d{2}:\d{2})(.\d{2})?)\s+(?<text>.+)/
    
    init(_ content: String) {
        self.content = content
    }
    
    func parse() -> [LyricSegment] {
        var lyricSegments: [LyricSegment] = []
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            if let segment = extract(line) {
                lyricSegments.append(segment)
            }
        }
        return lyricSegments
    }

    
    private func extract(_ line: String) -> LyricSegment? {
        let line = line.trimmingCharacters(in: .whitespaces)
        if line.isEmpty {
            return nil
        }
        if let match = line.wholeMatch(of: regex) {
            let res = LyricSegment(
                startedAt: toTimeInterval(match.startedAt.base),
                endedAt: toTimeInterval(match.endedAt.base),
                text: match.text.base)
            return res
        }
        return nil
    }

    // timstampString to TimeInterval
    private func toTimeInterval(_ timestamp: String) -> TimeInterval {
        let components = timestamp.components(separatedBy: ":")
        if components.isEmpty {
            return 0
        }
        let seconds = TimeInterval(components.last!) ?? 0.0
        let minutes = TimeInterval(components.first!) ?? 0.0
        if components.count == 3 {
            let hours = TimeInterval(components.first!) ?? 0.0
            let minutes = TimeInterval(components[1]) ?? 0.0
            return hours * 3600 + minutes * 60 + seconds
        }
        return minutes * 60 + seconds
    }
}
