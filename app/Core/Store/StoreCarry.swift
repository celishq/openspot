import Foundation

public struct StoreCarry: Equatable, Sendable {
    public let id: String
    public let size: SpotSize
    public private(set) var point: CGPoint

    public init(id: String, size: SpotSize, point: CGPoint) {
        self.id = id
        self.size = size
        self.point = point
    }

    public mutating func move(to next: CGPoint) {
        point = next
    }

    public var frame: CGRect {
        let width = SpotTokens.width(columns: size.columns)
        let height = SpotTokens.height(rows: size.rows)
        return CGRect(x: point.x - width / 2, y: point.y - height / 2, width: width, height: height)
    }

    public func lands(on target: CGRect?) -> Bool {
        target?.contains(point) == true
    }
}
