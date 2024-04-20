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
        guard let matches = url.fileName.wholeMatch(of: RegexPattern.movieName) else { return }
        let title = String(matches.output.title)
        let year = Int(matches.output.year ?? "")
        print("title \(title), year \(year)")
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

}
