import Foundation

public struct SpotSize: Equatable, Sendable {
    public let columns: Int
    public let rows: Int

    public static let small = SpotSize(columns: 1, rows: 1)
    public static let wide = SpotSize(columns: 2, rows: 1)
    public static let square = SpotSize(columns: 2, rows: 2)
    public static let strip = SpotSize(columns: 4, rows: 1)
    public static let large = SpotSize(columns: 4, rows: 2)

    /// Each size a person can prefer, from the smallest.
    public static let all: [SpotSize] = [.small, .wide, .square, .strip, .large]

    public init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
    }

    /// Whether a card of this size can take a larger size, or a smaller one, among these sizes.
    public func reach(among sizes: [SpotSize]) -> (grows: Bool, shrinks: Bool) {
        let area = columns * rows
        return (sizes.contains { $0.columns * $0.rows > area }, sizes.contains { $0.columns * $0.rows < area })
    }

    /// The word a file uses for this size.
    public var name: String {
        switch self {
        case .small: "small"
        case .wide: "wide"
        case .square: "square"
        case .strip: "strip"
        case .large: "large"
        default: "\(columns)x\(rows)"
        }
    }

    /// The size a file names: small, wide, square, strip or large.
    public init?(name: String) {
        switch name {
        case "small": self = .small
        case "wide": self = .wide
        case "square": self = .square
        case "strip": self = .strip
        case "large": self = .large
        default: return nil
        }
    }
}
