import CoreGraphics
import Foundation

/// The visible part of a square icon: the bounds of its opaque pixels, and the frame that draws the icon with its body at
/// the share of a standard app icon.
public struct IconBody: Equatable, Sendable {
    /// The share of the square that the larger side of a standard app icon's body fills.
    public static let share: CGFloat = 412 / 512
    private static let threshold: UInt8 = 32

    /// The opaque bounds, with the origin at the top left, or nil for an icon with no opaque pixel.
    public let bounds: CGRect?
    public let side: Int

    /// Reads the alpha of each pixel, row by row from the top, of a square of this side.
    public init(alpha: [UInt8], side: Int) {
        self.side = side
        var minX = side, minY = side, maxX = -1, maxY = -1
        for (index, value) in alpha.enumerated() where value > Self.threshold {
            let x = index % side, y = index / side
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        }
        bounds = maxX < 0 ? nil : CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    /// The frame, with the origin at the top left, in a square of this side, that draws the whole icon with its body
    /// centred and its larger side at the share of an app icon.
    public func frame(in square: CGFloat) -> CGRect {
        guard let bounds else { return CGRect(x: 0, y: 0, width: square, height: square) }
        let unit = square / CGFloat(side)
        let scale = square * Self.share / (max(bounds.width, bounds.height) * unit)
        let size = square * scale
        return CGRect(x: square / 2 - bounds.midX * unit * scale, y: square / 2 - bounds.midY * unit * scale, width: size, height: size)
    }
}
