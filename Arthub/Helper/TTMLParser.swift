//
//  TTMLParser.swift
//  Arthub
//
//  Created by 张鸿燊 on 13/2/2024.
//

import Foundation

class TTMLParser: NSObject, XMLParserDelegate {

    static let shared: TTMLParser = TTMLParser()
    
    private var lyrics: [Lyric] = []
    private var parsingP: Bool = false
    private var parsingSpan: Bool = false
    private var currentLyric: Lyric? = nil
        
    func parse(url: URL) -> [Lyric] {
        if let parser = XMLParser(contentsOf: url) {
            parser.delegate = self
            parser.parse()
        }
        print("parse TTML ended")
        return lyrics
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI titlespaceURI: String?, 
                qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "p" {
            parsingP = true
            currentLyric = Lyric()
            if  let lyric = currentLyric,
                let start = attributeDict["begin"],
                let end = attributeDict["end"] {
                lyric.start = timeInterval(start)
                lyric.end = timeInterval(end)
            }
        } else if elementName == "span" {
            parsingSpan = true
            if  let lyric = currentLyric,
                let start = attributeDict["begin"],
                let end = attributeDict["end"] {
                lyric.phrases.append(Lyric(start: timeInterval(start),
                                           end: timeInterval(end),
                                           content: ""))
            }
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if let lyric = currentLyric {
            if parsingP {
                parsingSpan ? lyric.phrases.last?.content.append(string) : lyric.content.append(string)
            }
        }
    }
        
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI titlespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "p" {
            parsingP = false
            if let lyric = currentLyric {
                lyrics.append(lyric)
                currentLyric = nil
            }
        } else if elementName == "span"{
            parsingSpan = false
        }
    }
    
    private func timeInterval(_ timeString: String) -> TimeInterval {
        let timeComponents = timeString.components(separatedBy: ":")
        let lastIndex = timeComponents.count - 1
        var res = 0.0
        guard lastIndex >= 0 else {
            return res
        }
        res += Double(timeComponents[lastIndex]) ?? 0
        guard lastIndex >= 1 else {
            return res
        }
        res += (Double(timeComponents[lastIndex - 1]) ?? 0) * 60
        guard lastIndex >= 2 else {
            return res
        }
        res += (Double(timeComponents[lastIndex - 2]) ?? 0) * 3600
        return res
    }
}
