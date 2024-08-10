//
//  Image+extensions.swift
//  VideoWithAVFoundation
//
//  Created by Itsuki on 2024/08/10.
//

import SwiftUI

extension CIImage {
    var cgImage: CGImage? {
        let ciContext = CIContext(options: nil)
        return ciContext.createCGImage(self, from: self.extent)
    }
}

extension CGImage {
    var image: Image? {
        return Image(decorative: self, scale: 1, orientation: .up)
    }
    
    
    var cvPixelBuffer: CVPixelBuffer? {
        let attributes = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary

        var pixelBuffer: CVPixelBuffer?
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            self.width,
            self.height,
            kCVPixelFormatType_32ARGB,
            attributes,
            &pixelBuffer
        )
        
        guard (status == kCVReturnSuccess) else {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        let context = CGContext(
            data: pixelData,
            width: self.width,
            height: self.height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        context?.draw(self, in: CGRect(x: 0, y: 0, width: self.width, height: self.height))

        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        return pixelBuffer

    }
    
}

