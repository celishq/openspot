import Foundation

public struct GridCell: Hashable, Sendable {
    public let row: Int
    public let column: Int

    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }

    public init?(text: String) {
        let parts = text.split(separator: " ").compactMap { Int($0) }
        guard parts.count == 2, parts.allSatisfy({ $0 >= 0 }) else { return nil }
        self.init(row: parts[0], column: parts[1])
    }
}
