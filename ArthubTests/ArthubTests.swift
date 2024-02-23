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
        let parser = TTMLParser.shared
        let lyrics = parser.parse(url: url)
        XCTAssert(lyrics[0].content == "City of stars")
        XCTAssert(lyrics[1].content == "Are you shining just for me?")
        
        
    }
    
    func testParseWordTTML() throws {
        let url = Bundle.main.url(forResource: "ttml-word", withExtension: "ttml")!
        let parser = TTMLParser.shared
        let lyrics = parser.parse(url: url)
        XCTAssert(lyrics[0].phrases[0].content == "I")
        XCTAssert(lyrics[0].phrases[1].content == "don't")
        XCTAssert(lyrics[0].phrases[2].content == "wanna")
        XCTAssert(lyrics[0].phrases[3].content == "be")
        XCTAssert(lyrics[0].phrases[4].content == "alone")
        XCTAssert(lyrics[0].phrases[5].content == "tonight")
    }
    

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
