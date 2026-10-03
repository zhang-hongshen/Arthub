//
//  ArthubTests.swift
//  ArthubTests
//
//  Created by 张鸿燊 on 2/2/2024.
//

import XCTest
@testable import Arthub
import AVFoundation

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

    func testExtras() {
        XCTAssertTrue(MediaNaming.isExtra(library.appending(path: "Movies/Inception-2010-trailer.mp4"), library: library))
        XCTAssertTrue(MediaNaming.isExtra(library.appending(path: "Movies/Inception (2010)/Deleted Scenes/Level 3.mkv"), library: library))
        XCTAssertFalse(MediaNaming.isExtra(library.appending(path: "Movies/The Big Short (2015).mkv"), library: library))
    }

    func testTrackNames() {
        let track = MediaNaming.parseTrack(library.appending(path: "Music/Adele/25 (2015)/Disc 1/01 Hello.flac"), library: library)
        XCTAssertEqual(track, MediaNaming.Track(title: "Hello", trackNumber: 1, discNumber: 1, album: "25", year: 2015, artist: "Adele"))
        XCTAssertEqual(MediaNaming.parseTrack(URL(fileURLWithPath: "/Media/Album/2-05 Song.mp3"), library: library).discNumber, 2)
    }

    func testSidecarParsing() {
        let srt = "1\n00:00:01,000 --> 00:00:02,500\n<i>Hello</i>\nworld\n\n2\n00:00:03,000 --> 00:00:04,000\nBye"
        XCTAssertEqual(SidecarParser.parseSRT(srt), [SubtitleCue(start: 1, end: 2.5, text: "Hello\nworld"),
                                                     SubtitleCue(start: 3, end: 4, text: "Bye")])
        let lyrics = SidecarParser.lyrics(lrc: "[ti:Song]\n[00:01.00][00:05.00]Hi\n[00:03.50]There")
        XCTAssertEqual(lyrics.map(\.content), ["Hi", "There", "Hi"])
        XCTAssertEqual(lyrics.map(\.start), [1, 3.5, 5])
    }

}
