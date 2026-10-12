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

    private static let backdropContext = CIContext()

    /// The image shrunk and blurred into soft patches of its own colours, each where it is in the image,
    /// for the background of the full-screen player.
    func backdrop(size: CGFloat = 256) -> CGImage? {
        guard extent.width > 0, extent.height > 0 else { return nil }
        let scale = size / max(extent.width, extent.height)
        let image = transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let output = image.clampedToExtent()
            .applyingGaussianBlur(sigma: size / 10)
            .cropped(to: image.extent)
            // Blurring greys the colours; bring them back, a little darker. The player washes them
            // further towards black or white for its text.
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.7,
                                                            kCIInputBrightnessKey: -0.08])
        return Self.backdropContext.createCGImage(output, from: output.extent)
    }

}
