//
//  TTMLParser.swift
//  Arthub
//
//  Created by 张鸿燊 on 13/2/2024.
//

import Foundation

class TTMLParser: NSObject {

    private var lyrics: [Lyric] = []
    private var currentLyric: Lyric? = nil
    /// Whether each open `<span>` is timed, innermost last.
    private var spans: [Bool] = []
    
    func parse(url: URL) -> [Lyric] {
        if let parser = XMLParser(contentsOf: url) {
            parser.delegate = self
            parser.parse()
        }
        print("parse TTML ended")
        return lyrics.sorted(using: KeyPathComparator(\Lyric.start, order: .forward))
    }
    
    func parse(data: Data) -> [Lyric] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        print("parse TTML ended")
        return lyrics.sorted(using: KeyPathComparator(\Lyric.start, order: .forward))
    }

}

extension TTMLParser: XMLParserDelegate {
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI titlespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "p" {
            currentLyric = Lyric()
            spans = []
            if  let lyric = currentLyric,
                let start = attributeDict["begin"],
                let end = attributeDict["end"] {
                lyric.start = timeInterval(start)
                lyric.end = timeInterval(end)
            }
        } else if elementName == "span", let lyric = currentLyric {
            if let start = attributeDict["begin"], let end = attributeDict["end"] {
                lyric.phrases.append(Lyric(start: timeInterval(start), end: timeInterval(end)))
                spans.append(true)
            } else {
                spans.append(false)
            }
        } else if elementName == "br", let lyric = currentLyric {
            lyric.content.append(" ")
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard let lyric = currentLyric else { return }
        // The line keeps all of its text, including the spaces between words.
        lyric.content.append(string)
        // Inside a timed span, even through an untimed one such as background vocals.
        if spans.contains(true), let phrase = lyric.phrases.last {
            phrase.content.append(string)
        }
    }
        
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI titlespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "p", let lyric = currentLyric {
            lyric.content = collapsed(lyric.content)
            for phrase in lyric.phrases {
                phrase.content = collapsed(phrase.content)
            }
            lyric.phrases.removeAll { $0.content.isEmpty }
            // Word-timed lines may leave the line itself untimed.
            if lyric.end <= lyric.start, let first = lyric.phrases.first, let last = lyric.phrases.last {
                lyric.start = first.start
                lyric.end = last.end
            }
            lyrics.append(lyric)
            currentLyric = nil
        } else if elementName == "span" {
            _ = spans.popLast()
        }
    }
    
    /// Indentation and line breaks in the markup become single spaces.
    private func collapsed(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
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
