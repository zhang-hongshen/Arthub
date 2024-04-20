//
//  MPMediaItemArtwork+.swift
//  Arthub
//
//  Created by 张鸿燊 on 1/3/2024.
//

import Foundation
import MediaPlayer
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

extension MPMediaItemArtwork {
    
    convenience init?(contentsOf url: URL) async {
        #if canImport(AppKit)
        var image: NSImage? = nil
        if url.isFileURL {
            image = NSImage(contentsOf: url)
        } else {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                image = NSImage(data: data)
            } catch {
                print("Error loading artwork from remote URL: \(error)")
            }
        }
        #elseif canImport(UIKit)
        var image: UIImage? = nil
        if url.isLocal {
            image = UIImage(contentsOf: url)
        } else {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                image = UIImage(data: data)
            } catch {
                print("Error loading artwork from remote URL: \(error)")
            }
        }
        #endif
        guard let image = image else {
            return nil
        }
        self.init(boundsSize: image.size) { size in
            return image
        }
    }
    
    convenience init?(data: Data) {
        #if canImport(AppKit)
        var image = NSImage(data: data)
        #elseif canImport(UIKit)
        var image = UIImage(data: data)
        #endif
        guard let image = image else {
            return nil
        }
        self.init(boundsSize: image.size) { size in
            return image
        }
    }
}
