//
//  ArthubTests.swift
//  ArthubTests
//
//  Created by 张鸿燊 on 2/2/2024.
//

import XCTest
@testable import Arthub

final class ArthubTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testParseLyrics() throws {
        let lyrics = Lyrics("""
            00:00:10.00 00:20.00 第一句歌词
            00:10.50 00:11.50 第二句歌词
            第三句歌词
            """)
            
        let lyricSegments = lyrics.parse()
            
        XCTAssertEqual(lyricSegments.count, 3, "Expected 3 lyric segments")
        
        XCTAssertEqual(lyricSegments[0].startedAt, 10.0)
        XCTAssertEqual(lyricSegments[0].endedAt, 20.0)
        XCTAssertEqual(lyricSegments[0].text, "第一句歌词")
        
        XCTAssertEqual(lyricSegments[1].startedAt, 10.5)
        XCTAssertEqual(lyricSegments[1].endedAt, 11.5)
        XCTAssertEqual(lyricSegments[1].text, "第二句歌词")
        
        XCTAssertNil(lyricSegments[2].startedAt)
        XCTAssertNil(lyricSegments[2].endedAt)
        XCTAssertEqual(lyricSegments[2].text, "第三句歌词")
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
