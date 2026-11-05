import Foundation

public struct SpotSize: Equatable, Sendable {
    public let columns: Int
    public let rows: Int

    public static let small = SpotSize(columns: 1, rows: 1)
    public static let wide = SpotSize(columns: 2, rows: 1)
    public static let square = SpotSize(columns: 2, rows: 2)
    public static let strip = SpotSize(columns: 4, rows: 1)
    public static let large = SpotSize(columns: 4, rows: 2)

    public init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
    }

    /// The size a plugin header names: small, wide, square or strip.
    public init?(name: String) {
        switch name {
        case "small": self = .small
        case "wide": self = .wide
        case "square": self = .square
        case "strip": self = .strip
        default: return nil
        }
    }
}
