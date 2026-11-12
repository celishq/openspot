import Foundation

/// Where the parts of a sheet go: a drawing in letters, or one column of lines.
public struct SheetLayout: Equatable, Sendable {
    public static let empty = "."
    public static let divider = "-"

    public let rows: [[String]]
    public let isDrawn: Bool
    public let areas: [String: SheetArea]
    /// The area that the rows of a script flow through, with how many rows go on one line.
    public let repeated: (area: String, perLine: Int)?
    let repeatCount: Int

    public static func == (first: SheetLayout, second: SheetLayout) -> Bool {
        first.rows == second.rows && first.isDrawn == second.isDrawn && first.repeated?.area == second.repeated?.area
            && first.repeated?.perLine == second.repeated?.perLine
    }

    /// Reads the layout block of a sheet, with the area of its repeat and how many rows go on its line. Returns nil when
    /// there is no `grid`.
    public init?(block: TextBlock?, repeating: (area: String, perLine: Int)? = nil, repeats: Int = 0) {
        let block = block ?? TextBlock(fields: [])
        let rows = block.values("grid").filter { !$0.isEmpty }.map(Self.words)
        repeated = repeating
        repeatCount = repeats
        guard !rows.isEmpty else { return nil }
        self.rows = rows
        isDrawn = true
        areas = Self.areas(in: rows)
    }

    /// The default drawing (protocol: Drawings): one column of lines in the order of the parts, then the area of the rows. A section with a
    /// title starts with a divider, and a section with no title is only a divider.
    public init(flat parts: [SpotPart], repeating: (area: String, perLine: Int)? = nil) {
        var rows: [[String]] = []
        for part in parts {
            if part.isSection, !rows.isEmpty { rows.append([Self.divider]) }
            if part.isSection, part.title == nil, part.press == .none, part.control == .none { continue }
            rows.append([part.id])
        }
        if let repeating { rows.append([repeating.area]) }
        self.rows = rows
        isDrawn = false
        areas = Self.areas(in: rows)
        repeated = repeating
        repeatCount = 0
    }

    /// The area a part fills, which its id names (protocol: Drawings).
    public func letter(of part: SpotPart) -> String? {
        part.id
    }

    public func hasDivider(inRow y: Int) -> Bool {
        rows.indices.contains(y) && rows[y].contains(Self.divider)
    }

    private static func words(_ line: String) -> [String] {
        line.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    private static func areas(in rows: [[String]]) -> [String: SheetArea] {
        var areas: [String: SheetArea] = [:]
        for (y, row) in rows.enumerated() {
            for (x, cell) in row.enumerated() where cell != empty && cell != divider {
                let area = SheetArea(x0: x, x1: x, y0: y, y1: y)
                areas[cell] = areas[cell]?.joined(area) ?? area
            }
        }
        return areas
    }
}
