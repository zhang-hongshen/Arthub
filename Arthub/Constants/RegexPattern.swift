//
//  RegexPattern.swift
//  Arthub
//
//  Created by 张鸿燊 on 19/2/2024.
//

import Foundation

struct RegexPattern {
    // title (Year)
    static let movieName = /(?<title>.*?)\s*((\(|\[)?(?<year>\d{4})(\)|\])?\s*)?/
    // order {-} title
    static let musicName = /((?<discNumber>\d*\s*[-])?\s*(?<trackNumber>\d*))?\s*(\-)?(?<title>.*)\s*/
    
    static let tvepisodeName = /(?<title>.*?)\s*[S|s](?<seasonNum>\d*)[E|e](?<episodeNum>\d*)\s*/
}
