import Foundation

public struct SpotSize: Hashable, Sendable {
    public let columns: Int
    public let rows: Int

    public static let small = SpotSize(columns: 1, rows: 1)
    public static let wide = SpotSize(columns: 2, rows: 1)
    public static let square = SpotSize(columns: 2, rows: 2)
    public static let strip = SpotSize(columns: 4, rows: 1)
    public static let large = SpotSize(columns: 4, rows: 2)

    private static let named: [(name: String, size: SpotSize)] = [
        ("small", .small), ("wide", .wide), ("square", .square), ("strip", .strip), ("large", .large),
    ]

    public static let all = named.map(\.size)

    public init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
    }

    public func reach(among sizes: [SpotSize]) -> (grows: Bool, shrinks: Bool) {
        let area = columns * rows
        return (sizes.contains { $0.columns * $0.rows > area }, sizes.contains { $0.columns * $0.rows < area })
    }

    public var name: String {
        Self.named.first { $0.size == self }?.name ?? "\(columns)x\(rows)"
    }

    public init?(name: String) {
        guard let size = Self.named.first(where: { $0.name == name })?.size else { return nil }
        self = size
    }
}
