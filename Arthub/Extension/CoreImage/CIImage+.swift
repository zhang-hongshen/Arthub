//
//  CIImage+.swift
//  Arthub
//
//  Created by 张鸿燊 on 12/3/2024.
//

import CoreImage

extension CIImage {
    
    var averageColor: CGColor? {
        let extentVector = CIVector(x: extent.origin.x,
                                    y: extent.origin.y,
                                    z: extent.size.width,
                                    w: extent.size.height)
        
        guard let filter = CIFilter(name: "CIAreaAverage",
                                    parameters: [kCIInputImageKey: self, kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        
        let context = CIContext(options: [.workingColorSpace: kCFNull])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        return CGColor(red: CGFloat(bitmap[0]) / 255,
                       green: CGFloat(bitmap[1]) / 255,
                       blue: CGFloat(bitmap[2]) / 255,
                       alpha: CGFloat(bitmap[3]) / 255)
    }
    
}
