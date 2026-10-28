//
//  ArthubTests.swift
//  ArthubTests
//
//  Created by 张鸿燊 on 2/2/2024.
//

import XCTest
@testable import Arthub
import AVFoundation
import SwiftData

final class ArthubTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testParseLineTTML() throws {
        let url = Bundle.main.url(forResource: "ttml-line", withExtension: "ttml")!
        let lyrics = TTMLParser().parse(url: url)
        XCTAssert(lyrics[0].content == "City of stars")
        XCTAssert(lyrics[1].content == "Are you shining just for me?")
    }
    
    func testParseWordTTML() throws {
        let url = Bundle.main.url(forResource: "ttml-word", withExtension: "ttml")!
        let lyrics =  TTMLParser().parse(url: url)
        XCTAssert(lyrics[0].phrases[0].content == "I")
        XCTAssert(lyrics[0].phrases[1].content == "don't")
        XCTAssert(lyrics[0].phrases[2].content == "wanna")
        XCTAssert(lyrics[0].phrases[3].content == "be")
        XCTAssert(lyrics[0].phrases[4].content == "alone")
        XCTAssert(lyrics[0].phrases[5].content == "tonight")
        XCTAssertEqual(lyrics[0].content, "I don't wanna be alone tonight")
    }
    
    func testURLHasDirectoryPath() {
        print(URL(string: "file:///Users/zhanghongshen/Movies/Arthub/Movies/")!.hasDirectoryPath)
        let url = URL(string:  "file:///Users/zhanghongshen/Movies/Arthub/Movies/%E9%99%B6%E5%96%86Love%20Can%E9%A6%99%E6%B8%AF%E6%BC%94%E5%94%B1%E4%BC%9A%20(2006)/%E9%99%B6%E5%96%86Love%20Can%E9%A6%99%E6%B8%AF%E6%BC%94%E5%94%B1%E4%BC%9A%20(2006).mp4")!
        print(String(describing: MediaNaming.parseMovie(url)))
    }
    
    
    func testURLAppending() throws {
        let url = URL(string: "https://com.example.com")!
        print(url.appending(queryItems: [URLQueryItem(name: "apikey", value: "1 2 3")]))
        print(url.appending(component: "456", directoryHint: .isDirectory))
        print(url.appending(component: "456", directoryHint: .notDirectory))
        print(url.appending(component: "456", directoryHint: .checkFileSystem))
        print(url.appending(component: "456", directoryHint: .inferFromPath))
        print(url.appending(path: "a r t i s t"))
        print(url.appending(components: "456", "456", directoryHint: .notDirectory))
        let url2 =  URL(string: "file:///Users/zhanghongshen/Movies/Arthub/Movies/")
        guard let url2 else { print("nil"); return }
        print(url2.formatted())
    }
    
    func testURLProperty() throws {
        let url = Bundle.main.url(forResource: "ttml-word", withExtension: "ttml")!
        print("scheme: \(url.scheme ?? "")")
        var volumeURL = try  url.resourceValues(forKeys: [.volumeURLKey]).volume
        var parentDirectory = try url.resourceValues(forKeys:[.parentDirectoryURLKey]).parentDirectory
        print("volume \(volumeURL?.absoluteString ?? "")")
        print("parentDirectory \(parentDirectory?.absoluteString ?? "")")
        
        var urlComponents = URLComponents(string: "//localhost:8888/webdav")!
        urlComponents.scheme = "https"
        print(urlComponents.url?.relativeString ?? "")
        print(urlComponents.url?.baseURL?.relativeString ?? "")
    }
    
    func testCifilter() throws {
       print(CIFilter.filterNames(inCategory: kCICategoryHighDynamicRange).formatted())
    }
    
    func testTTMLWrite() throws {
        // 创建XML文档
        let ttmlDocument = XMLDocument()
        // create root <tt>
        let rootElement = XMLElement(name: "tt")
        rootElement.addAttribute(XMLNode.attribute(withName: "xmlns", stringValue: "http://www.w3.org/ns/ttml") as! XMLNode)
        rootElement.addAttribute(XMLNode.attribute(withName: "xmlns:ttm", stringValue: "http://www.w3.org/ns/ttml#metadata") as! XMLNode)
        ttmlDocument.setRootElement(rootElement)
        // add <head>
        let headElement = XMLElement(name: "head")
        let metadataElement = XMLElement(name: "metadata")
        let titleElement = XMLElement(name: "ttm:title")
        titleElement.setStringValue("安静", resolvingEntities: true)
        metadataElement.addChild(titleElement)
        headElement.addChild(metadataElement)
        rootElement.addChild(headElement)
        
        // add <body>
        let bodyElement = XMLElement(name: "body")
        bodyElement.addAttribute(XMLNode.attribute(withName: "dur", stringValue: TimeInterval(90).formatted()) as! XMLNode )
        let divElement = XMLElement(name: "div")
        let pElement = XMLElement(name: "p")
        pElement.addAttribute(XMLNode.attribute(withName: "begin", stringValue: TimeInterval(0).formatted()) as! XMLNode)
        pElement.addAttribute(XMLNode.attribute(withName: "end", stringValue: TimeInterval(5).formatted()) as! XMLNode)
        pElement.setStringValue("歌词", resolvingEntities: true)
        divElement.addChild(pElement)
        bodyElement.addChild(divElement)
        rootElement.addChild(bodyElement)
        // 保存TTML文档到文件
        let fileURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            .appending(component: "test").appendingPathExtension(for: .ttml)
        do {
            try ttmlDocument.xmlData(options: [.nodePrettyPrint]).write(to: fileURL)
            print("TTML document saved successfully.")
        } catch {
            print("Error saving TTML document: \(error)")
        }

    }
    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

    // MARK: Naming

    private let library = URL(fileURLWithPath: "/Media")

    func testMovieNames() {
        let cases: [(String, String, Int?)] = [
            ("Movies/Pulp Fiction (1994).mkv", "Pulp Fiction", 1994),
            ("Movies/Inception.avi", "Inception", nil),
            ("Movies/Captain-America-The-Winter-Soldier-2014.mp4", "Captain America The Winter Soldier", 2014),
            ("Movies/The.Matrix.1999.1080p.BluRay.x264.mkv", "The Matrix", 1999),
            ("Movies/1917 (2019).mkv", "1917", 2019),
            ("Movies/Blade Runner (1982)/Blade Runner (1982) Director's Cut cd1.mkv", "Blade Runner", 1982),
            ("Movies/Inception (2010)/movie.mkv", "Inception", 2010),
        ]
        for (path, title, year) in cases {
            guard case .movie(let movie) = MediaNaming.parseVideo(library.appending(path: path), library: library) else {
                XCTFail(path); continue
            }
            XCTAssertEqual(movie.title, title, path)
            XCTAssertEqual(movie.year, year, path)
        }
        let pinned = MediaNaming.parseMovie(name: "Inception {tmdb-27205} {edition-Extended}")
        XCTAssertEqual(pinned, MediaNaming.Movie(title: "Inception", tmdbID: 27205))
    }

    func testEpisodeNames() {
        let cases: [(String, String, Int, Int)] = [
            ("show-name_s01.e02.mkv", "show name", 1, 2),
            ("show-name_s1e2.mkv", "show name", 1, 2),
            ("show-name_1x02.mkv", "show name", 1, 2),
            ("show-name_se1.ep2.mkv", "show name", 1, 2),
            ("show-name-season1.episode2.mkv", "show name", 1, 2),
            ("TV Shows/Show Name/any folder/S01E02.mkv", "Show Name", 1, 2),
            ("TV Shows/Show Name/any folder/01.02 NameOfEpisode.mkv", "Show Name", 1, 2),
            ("TV Shows/Show Name/Season 1/02 NameOfEpisode.mkv", "Show Name", 1, 2),
            ("TV Shows/Show Name/Season 1/1-02 NameOfEpisode.mkv", "Show Name", 1, 2),
            ("TV Shows/Show Name/Season 1/episode 02 - NameOfEpisode.mkv", "Show Name", 1, 2),
            ("TV Shows/Show Name/第二季/第05集.mkv", "Show Name", 2, 5),
            ("Breaking-Bad.S00.E01.mkv", "Breaking Bad", 0, 1),
            ("Mad Men S01 E01 720p.mp4", "Mad Men", 1, 1),
        ]
        for (path, show, season, episode) in cases {
            guard case .episode(let parsed) = MediaNaming.parseVideo(library.appending(path: path), library: library) else {
                XCTFail(path); continue
            }
            XCTAssertEqual(parsed.show, show, path)
            XCTAssertEqual(parsed.season, season, path)
            XCTAssertEqual(parsed.episode, episode, path)
        }
        // The show folder groups episodes whose file names disagree.
        let folder = "TV Shows/Doctor Who (2005)/Season 01/"
        for name in ["Doctor.Who.S01E01.mkv", "DW S01E02.mkv"] {
            guard case .episode(let parsed) = MediaNaming.parseVideo(library.appending(path: folder + name), library: library) else {
                XCTFail(name); continue
            }
            XCTAssertEqual(parsed.show, "Doctor Who")
            XCTAssertEqual(parsed.year, 2005)
        }
        guard case .episode(let multi) = MediaNaming.parseVideo(library.appending(path: "Show S01E01-E02.mkv"), library: library) else {
            return XCTFail("multi-episode")
        }
        XCTAssertEqual(multi.episodes, [1, 2])
        XCTAssertNotNil(MediaNaming.parseVideo(library.appending(path: "Movies/Avatar 1920x1080.mkv"), library: library)
            .flatMap { if case .movie = $0 { true } else { nil } })
    }

    func testVersions() {
        let cases: [(String, String, String?)] = [
            ("Inception (2010) - 4K.mkv", "Inception", "4K"),
            ("Inception (2010) - Director's Cut.mkv", "Inception", "Director's Cut"),
            ("Inception (2010) {edition-Extended}.mkv", "Inception", "Extended"),
            ("Inception (2010).mkv", "Inception", nil),
            ("Mission Impossible - Fallout (2018).mkv", "Mission Impossible - Fallout", nil),
        ]
        for (name, title, version) in cases {
            let url = library.appending(path: "Movies/" + name)
            XCTAssertEqual(MediaNaming.versionName(url), version, name)
            guard case .movie(let movie) = MediaNaming.parseVideo(url, library: library) else { XCTFail(name); continue }
            XCTAssertEqual(movie.title, title, name)
        }
        XCTAssertEqual(MediaNaming.nameWithoutVersion(library.appending(path: "Inception (2010) - 4K.mkv")), "Inception (2010)")
        XCTAssertEqual(MediaNaming.videoWidth(named: "The.Matrix.1999.2160p.BluRay"), 3840)
        XCTAssertNil(MediaNaming.videoWidth(named: "Avatar 1920x1080"))
    }

    func testExtras() {
        XCTAssertTrue(MediaNaming.isExtra(library.appending(path: "Movies/Inception-2010-trailer.mp4"), library: library))
        XCTAssertTrue(MediaNaming.isExtra(library.appending(path: "Movies/Inception (2010)/Deleted Scenes/Level 3.mkv"), library: library))
        XCTAssertFalse(MediaNaming.isExtra(library.appending(path: "Movies/The Big Short (2015).mkv"), library: library))
    }

    func testTrackNames() {
        let track = MediaNaming.parseTrack(library.appending(path: "Music/Adele/25 (2015)/Disc 1/01 Hello.flac"), library: library)
        XCTAssertEqual(track, MediaNaming.Track(title: "Hello", trackNumber: 1, discNumber: 1, album: "25", year: 2015, artist: "Adele"))
        XCTAssertEqual(MediaNaming.parseTrack(URL(fileURLWithPath: "/Media/Album/2-05 Song.mp3"), library: library).discNumber, 2)
        // Without an album folder, the folder is the artist once the tags name the album.
        let single = library.appending(path: "Music/Adele/01 Hello.mp3")
        XCTAssertEqual(MediaNaming.parseTrack(single, library: library, album: "25").artist, "Adele")
        XCTAssertEqual(MediaNaming.parseTrack(single, library: library).album, "Adele")
        XCTAssertEqual(MediaNaming.parseTrack(library.appending(path: "Music/Adele/25 (2015)/01 Hello.mp3"),
                                              library: library, album: "25 (Deluxe)").artist, "Adele")
    }

    func testFLACTags() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).flac")
        defer { try? FileManager.default.removeItem(at: url) }
        // Stream info as the only block, then stand-in audio.
        try (Data("fLaC".utf8) + [0x80, 0, 0, 34] + Data(count: 34) + [1, 2, 3]).write(to: url)
        let cover = Data([0x89, 0x50, 0x4E, 0x47])
        try await AudioTags.write([.album("25"), .trackNumber(1), .cover(cover)], to: url)
        let tags = try XCTUnwrap(AudioTags.readFLAC(url))
        XCTAssertEqual(tags.comments["ALBUM"], "25")
        XCTAssertEqual(tags.comments["TRACKNUMBER"], "1")
        XCTAssertEqual(tags.cover, cover)
        XCTAssertEqual(try Data(contentsOf: url).suffix(3), Data([1, 2, 3]))
    }

    func testSidecarParsing() {
        let srt = "1\n00:00:01,000 --> 00:00:02,500\n<i>Hello</i>\nworld\n\n2\n00:00:03,000 --> 00:00:04,000\nBye"
        XCTAssertEqual(SidecarParser.parseSRT(srt), [SubtitleCue(start: 1, end: 2.5, text: "Hello\nworld"),
                                                     SubtitleCue(start: 3, end: 4, text: "Bye")])
        let lyrics = SidecarParser.lyrics(lrc: "[ti:Song]\n[00:01.00][00:05.00]Hi\n[00:03.50]There")
        XCTAssertEqual(lyrics.map(\.content), ["Hi", "There", "Hi"])
        XCTAssertEqual(lyrics.map(\.start), [1, 3.5, 5])
        // `[mm:ss]`, a translation sharing its line's time, word timing, and a timestamp ending the last line.
        let timed = SidecarParser.lyrics(lrc: "[00:01]A\n[00:02.00]B\n[00:02.00]乙\n[00:04.50]<00:04.50>只<00:05.00>剩下<00:05.50>\n[00:07.00]")
        XCTAssertEqual(timed.map(\.content), ["A", "B", "乙", "只剩下"])
        XCTAssertEqual(timed.map(\.end), [2, 4.5, 4.5, 7])
        XCTAssertEqual(timed[3].phrases.map(\.end), [5, 5.5])
        XCTAssertEqual(SidecarParser.lyrics(lrc: Lyric.lrc(timed)).map(\.end), [2, 4.5, 4.5, 7])
        // ID3 SYLT in UTF-8 with millisecond timestamps, one line per entry.
        var sylt: [UInt8] = [3] + Array("eng".utf8) + [2, 1, 0]
        for (text, milliseconds) in [("Hello", UInt32(1000)), ("World", 2500)] {
            sylt += Array(text.utf8) + [0] + withUnsafeBytes(of: milliseconds.bigEndian) { Array($0) }
        }
        XCTAssertEqual(SidecarParser.lyrics(sylt: Data(sylt)).map(\.start), [1, 2.5])
    }

    func testLRCLIBRecord() throws {
        let json = #"{"id":1,"trackName":"Hello","artistName":"Adele","albumName":"25","duration":296.0,"instrumental":false,"plainLyrics":"Hello, it's me","syncedLyrics":"[00:06.50] Hello, it's me"}"#
        let record = try JSONDecoder().decode(LRCLIB.Record.self, from: Data(json.utf8))
        XCTAssertEqual(record.lyrics.map(\.start), [6.5])
        XCTAssertEqual(record.plainLines.map(\.content), ["Hello, it's me"])
        XCTAssertEqual(record.plainLines.map(\.end), [0])
    }

    func testNetEaseYRC() {
        // A credit line, then words held past the next line.
        let yrc = "[0,1000](0,1000,0) 作词 : 方文山\n[5430,3000](5430,240,0)I (5670,240,0)stay(5910,180,0), (6090,180,0)late\n[8000,1000](8000,500,0)如(8500,500,0)果"
        let lyrics = NetEase.lyrics(yrc: yrc)
        XCTAssertEqual(lyrics.map(\.content), ["I stay, late", "如果"])
        XCTAssertEqual(lyrics.map(\.end), [8, 9])
        XCTAssertEqual(lyrics[0].phrases.map(\.content), ["I", "stay", ",", "late"])
        XCTAssertNotNil(lyrics[0].segments)
        XCTAssertEqual("十年 (Live)".matchKey, "十年(live)".matchKey)
        XCTAssertTrue("周杰倫 Jay Chou".isSameArtist(as: "周杰伦"))
        XCTAssertTrue("周杰倫 Jay Chou".isSameArtist(as: "Jay Chou (周杰倫)"))
        XCTAssertFalse("周杰倫 Jay Chou".isSameArtist(as: "Lucky小爱"))
    }

    func testLyricsShift() {
        let lyrics = LyricsDetail(body: SidecarParser.lyrics(lrc: "[00:01.00]<00:01.00>微<00:02.00>笑\n[00:04.00]"))
        lyrics.shift(by: -1.5)
        XCTAssertEqual(lyrics.body.map(\.start), [-0.5])
        XCTAssertEqual(lyrics.body[0].phrases.map(\.start), [-0.5, 0.5])
        XCTAssertTrue(lyrics.isUnsaved)
        // Times before the song starts are written as its start.
        XCTAssertEqual(Lyric.lrc(lyrics.body), "[00:00.00]<00:00.00>微<00:00.50>笑\n[00:02.50]\n")
    }

    @MainActor
    func testWatchProgress() throws {
        let store = WatchProgressStore()
        let movie = store.metrics(.movie, tmdbID: 603)
        XCTAssertTrue(movie === store.metrics(.movie, tmdbID: 603))
        // TMDb numbers movies and episodes separately.
        XCTAssertFalse(movie === store.metrics(.episode, tmdbID: 603))
        store.record(120, for: movie)
        // Saved, so another context reads it back.
        let saved = try ModelContext(store.container).fetch(FetchDescriptor<UserMetrics>(
            predicate: #Predicate { $0.key == "movie/603" }))
        XCTAssertEqual(saved.map(\.currentTime), [120])
        XCTAssertNotNil(saved.first?.watchedAt)
    }

}
