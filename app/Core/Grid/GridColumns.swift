import Foundation

public struct GridColumns: Equatable, Sendable {
    public static let choices = [4, 6, 8]

    public let count: Int

    public init(_ count: Int = SpotTokens.columns) {
        self.count = Self.choices.contains(count) ? count : SpotTokens.columns
    }

    public var layout: GridLayout {
        GridLayout(columns: count)
    }

    public var row: SpotSize {
        SpotSize(columns: count, rows: 1)
    }

    public var frame: CGRect {
        CGRect(x: 0, y: 0, width: SpotTokens.panelWidth, height: SpotTokens.panelHeight)
    }
}
