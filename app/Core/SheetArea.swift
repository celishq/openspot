import Foundation

/// The cells that a letter of a drawing covers, as a rectangle of columns and rows.
public struct SheetArea: Equatable, Sendable {
    public var x0: Int
    public var x1: Int
    public var y0: Int
    public var y1: Int

    public init(x0: Int, x1: Int, y0: Int, y1: Int) {
        self.x0 = x0
        self.x1 = x1
        self.y0 = y0
        self.y1 = y1
    }

    public var size: Int {
        (x1 - x0 + 1) * (y1 - y0 + 1)
    }

    public func hits(_ other: SheetArea) -> Bool {
        x0 <= other.x1 && other.x0 <= x1 && y0 <= other.y1 && other.y0 <= y1
    }

    public func joined(_ other: SheetArea) -> SheetArea {
        SheetArea(x0: min(x0, other.x0), x1: max(x1, other.x1), y0: min(y0, other.y0), y1: max(y1, other.y1))
    }
}
