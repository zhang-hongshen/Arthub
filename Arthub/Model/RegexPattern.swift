//
//  RegexPattern.swift
//  Arthub
//
//  Created by 张鸿燊 on 19/2/2024.
//

import Foundation

struct RegexPattern {
    // title (Year)
    static let movieName = /(?<title>.*?)\s*(\()?(?<year>\d{4})(\))?\s*/
    // order {-} title
    static let musicName = /((?<discNum>\d*\s*[-])?\s*(?<trackNum>\d*))?\s*(\-)?(?<title>.*)\s*/
}
