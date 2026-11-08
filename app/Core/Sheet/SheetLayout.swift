import Foundation

/// Where the parts of a sheet go: a drawing in letters, or one column of lines.
public struct SheetLayout: Equatable, Sendable {
    public static let empty = "."
    public static let divider = "-"

    public let rows: [[String]]
    public let cards: [[String]]
    public let isDrawn: Bool
    public let keyParts: [SpotPart]
    public let areas: [String: SheetArea]
    /// The area that the rows of a script flow through, with how many rows go on one line.
    public let repeated: (area: String, perLine: Int)?
    let repeatCount: Int

    public static func == (first: SheetLayout, second: SheetLayout) -> Bool {
        first.rows == second.rows && first.cards == second.cards && first.isDrawn == second.isDrawn
            && first.keyParts == second.keyParts && first.repeated?.area == second.repeated?.area
            && first.repeated?.perLine == second.repeated?.perLine
    }

    /// Reads the layout block of a sheet, with the area of its repeat and how many rows go on its line. Returns nil when
    /// there is no `grid` or `keys`.
    public init?(block: TextBlock?, repeating: (area: String, perLine: Int)? = nil, repeats: Int = 0) {
        let block = block ?? TextBlock(fields: [])
        var rows: [[String]] = []
        var keys: [SpotPart] = []
        let cards = block.values("card").map(Self.words)
        for field in block.fields where !field.value.isEmpty {
            if field.key == "grid" { rows.append(Self.words(field.value)) }
            if field.key == "pad" {
                let words = Self.words(field.value)
                rows.append(words.map(Self.keyCell))
                for word in words where !keys.contains(where: { $0.id == word }) {
                    if let part = Self.keyPart(word) { keys.append(part) }
                }
            }
        }
        repeated = repeating
        repeatCount = repeats
        guard !rows.isEmpty else { return nil }
        self.rows = rows
        self.cards = cards
        isDrawn = true
        keyParts = keys
        areas = Self.areas(in: rows)
    }

    /// The default drawing (U13): one column of lines in the order of the parts, then the area of the rows. A section with a
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
        cards = []
        isDrawn = false
        keyParts = []
        areas = Self.areas(in: rows)
        repeated = repeating
        repeatCount = 0
    }

    /// The area a part fills, which its id names (U4). A key of a keypad fills the cell of its word.
    public func letter(of part: SpotPart) -> String? {
        part.look == .pad ? Self.keyCell(part.id) : part.id
    }

    public func hasDivider(inRow y: Int) -> Bool {
        rows.indices.contains(y) && rows[y].contains(Self.divider)
    }

    private static func words(_ line: String) -> [String] {
        line.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    /// The cell of a key. The two marks of a drawing are also keys of a keypad, so they take a cell of their own.
    private static func keyCell(_ word: String) -> String {
        word == empty || word == divider ? "key\(word)" : word
    }

    private static func keyPart(_ word: String) -> SpotPart? {
        SpotPart(block: TextBlock(fields: [
            .init(key: "button", value: word),
            .init(key: "title", value: word),
            .init(key: "look", value: "pad")
        ]))
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
