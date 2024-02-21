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

    func testParseTTML() throws {
        let url = Bundle.main.url(forResource: "ttml", withExtension: "ttml")!
        let parser = TTMLParser.shared
        let lyrics = parser.parse(url: url)
        XCTAssert(lyrics[0].content == "City of stars")
        XCTAssert(lyrics[1].content == "Are you shining just for me?")
    }

    func testURL() {

        print(FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!.relativePath)
        print(FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first!.relativePath)
    }
    
    
    func testLoadMediaSelectionOptions() async throws {
        let url = URL(string:  "file:///Users/zhanghongshen/Movies/Arthub/Aquaman%20and%20the%20Lost%20Kingdom%20(2023)/Aquaman%20and%20the%20Lost%20Kingdom%20(2023).mp4")
        
        let asset = AVURLAsset(url: url!)
        for characteristic in try await asset.load(.availableMediaCharacteristicsWithMediaSelectionOptions) {
            debugPrint("\(characteristic)")
            // Retrieve the AVMediaSelectionGroup for the specified characteristic.
            if let group = try await asset.loadMediaSelectionGroup(for: characteristic) {
                // Print its options.
                for option in group.options {
                    debugPrint("  Option: \(option.displayName)")
                }
            }
        }
    }
    
    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
