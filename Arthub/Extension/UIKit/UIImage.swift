//
//  UIImage+.swift
//  Arthub
//
//  Created by 张鸿燊 on 6/3/2024.
//

#if canImport(UIKit)
import UIKit

extension UIImage {
    
    convenience init?(contentsOf url: URL) {
        do {
            let data = try Data(contentsOf: url)
            self.init(data: data)
        } catch {
            return nil
        }
    }
}
#endif
