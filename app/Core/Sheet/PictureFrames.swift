import CoreGraphics
import Foundation

public final class PictureFrames: Sendable {
    public let images: [CGImage]
    public let delays: [Double]
    public let size: CGSize

    init(images: [CGImage], delays: [Double], size: CGSize) {
        self.images = images
        self.delays = delays
        self.size = size
    }

    public var duration: Double {
        delays.reduce(0, +)
    }

    public var keyTimes: [Double] {
        let duration = duration
        return delays.reduce(into: [0]) { $0.append($0[$0.count - 1] + $1) }.map { $0 / duration }
    }

    public var bytes: Int {
        images.reduce(0) { $0 + $1.bytesPerRow * $1.height }
    }

    public static func moves(_ path: String) -> Bool {
        (path as NSString).pathExtension.lowercased() == "gif"
    }
}
