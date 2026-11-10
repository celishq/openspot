import Foundation

/// The size of the panel's grid that the person sets: its columns, in steps of four from 4 to 16, and the rows that it shows.
public struct PanelSize: Equatable, Sendable {
    public let columns: Int
    public let rows: Int

    public static let standard = PanelSize(columns: 4, rows: 6)
    public static let columnSteps = [4, 8, 12, 16]

    public init(columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
    }

    /// The size that a file names as columns by rows, such as `8x6`, or nil for one that the panel cannot take.
    public init?(text: String) {
        let parts = text.split(separator: "x").compactMap { Int($0) }
        guard parts.count == 2, Self.columnSteps.contains(parts[0]), parts[1] > 0 else { return nil }
        self.init(columns: parts[0], rows: parts[1])
    }

    /// The words a file uses for this size.
    public var text: String {
        "\(columns)x\(rows)"
    }
}
