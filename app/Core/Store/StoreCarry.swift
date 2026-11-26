import CoreGraphics
import Foundation

public struct StoreCarry: Equatable, Sendable {
    public let id: String
    public let size: SpotSize
    public let grab: CGPoint
    public private(set) var point: CGPoint

    public init(id: String, size: SpotSize, point: CGPoint, grab: CGPoint = CGPoint(x: 0.5, y: 0.5)) {
        self.id = id
        self.size = size
        self.point = point
        self.grab = CGPoint(x: min(max(grab.x, 0), 1), y: min(max(grab.y, 0), 1))
    }

    public mutating func move(to next: CGPoint) {
        point = next
    }

    public var frame: CGRect {
        let width = SpotTokens.width(columns: size.columns)
        let height = SpotTokens.height(rows: size.rows)
        return CGRect(x: point.x - width * grab.x, y: point.y - height * grab.y, width: width, height: height)
    }

    public func lands(on target: CGRect?) -> Bool {
        target?.contains(point) == true
    }
}
