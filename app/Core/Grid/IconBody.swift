import CoreGraphics
import Foundation

public struct IconBody: Equatable, Sendable {
    public static let share: CGFloat = 412 / 512
    private static let threshold: UInt8 = 32

    public let bounds: CGRect?
    public let side: Int

    public init(alpha: [UInt8], side: Int) {
        self.side = side
        var minX = side, minY = side, maxX = -1, maxY = -1
        for (index, value) in alpha.enumerated() where value > Self.threshold {
            let x = index % side, y = index / side
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        }
        bounds = maxX < 0 ? nil : CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    public func frame(in square: CGFloat) -> CGRect {
        guard let bounds else { return CGRect(x: 0, y: 0, width: square, height: square) }
        let unit = square / CGFloat(side)
        let scale = square * Self.share / (max(bounds.width, bounds.height) * unit)
        let size = square * scale
        return CGRect(x: square / 2 - bounds.midX * unit * scale, y: square / 2 - bounds.midY * unit * scale, width: size, height: size)
    }
}
