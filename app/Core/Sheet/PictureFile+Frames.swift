import CoreGraphics
import Foundation
import ImageIO

extension PictureFile {
    private static let shortestDelay = 0.011
    private static let plainDelay = 0.1
    private static let rowAlignment = 64

    public func readFrames(shortSide: Int, bytes: Int) -> PictureFrames? {
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 1, let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0 else { return nil }
        let side = Self.longSide(width: width, height: height, shortSide: shortSide, bytes: bytes / count)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: side
        ]
        var images: [CGImage] = []
        var delays: [Double] = []
        for index in 0..<count {
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary) else { continue }
            images.append(image)
            delays.append(Self.time(of: CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]))
        }
        guard images.count > 1 else { return nil }
        return PictureFrames(images: images, delays: delays, size: CGSize(width: width, height: height))
    }

    private static func longSide(width: Int, height: Int, shortSide: Int, bytes: Int) -> Int {
        let short = min(width, height)
        let long = max(width, height)
        var side = short > shortSide ? long * shortSide / short : long
        while side > 1, frameBytes(long: side, width: width, height: height) > bytes { side -= 1 }
        return max(side, 1)
    }

    private static func frameBytes(long: Int, width: Int, height: Int) -> Int {
        let scale = Double(long) / Double(max(width, height))
        let columns = max(Int((Double(width) * scale).rounded()), 1)
        let rows = max(Int((Double(height) * scale).rounded()), 1)
        return (columns * 4 + rowAlignment - 1) / rowAlignment * rowAlignment * rows
    }

    private static func time(of properties: [CFString: Any]?) -> Double {
        let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        let delay = gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double ?? gif?[kCGImagePropertyGIFDelayTime] as? Double ?? 0
        return delay < shortestDelay ? plainDelay : delay
    }
}
