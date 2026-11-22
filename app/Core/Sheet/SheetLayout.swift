import Foundation

public struct SheetLayout: Equatable, Sendable {
    public let rows: [[String]]
    public let areas: [String: SheetArea]
    public let repeated: (area: String, perLine: Int)?

    public static func == (first: SheetLayout, second: SheetLayout) -> Bool {
        first.rows == second.rows && first.repeated?.area == second.repeated?.area && first.repeated?.perLine == second.repeated?.perLine
    }

    public init(flat parts: [SpotPart], repeating: (area: String, perLine: Int)? = nil) {
        var rows: [[String]] = []
        for part in parts {
            rows += Array(repeating: [part.id], count: part.flatLines)
        }
        if let repeating { rows.append([repeating.area]) }
        self.rows = rows
        areas = Self.areas(in: rows)
        repeated = repeating
    }

    public func letter(of part: SpotPart) -> String? {
        part.id
    }

    private static func areas(in rows: [[String]]) -> [String: SheetArea] {
        var areas: [String: SheetArea] = [:]
        for (y, row) in rows.enumerated() {
            for (x, cell) in row.enumerated() {
                let area = SheetArea(x0: x, x1: x, y0: y, y1: y)
                areas[cell] = areas[cell]?.joined(area) ?? area
            }
        }
        return areas
    }
}
