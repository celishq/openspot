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

    /// Reads the layout block of a sheet. Returns nil when the block has no `grid`, `keys` or `repeat`.
    public init?(block: TextBlock) {
        var rows: [[String]] = []
        var keys: [SpotPart] = []
        let cards = block.values("card").map(Self.words)
        for field in block.fields where !field.value.isEmpty {
            if field.key == "grid" { rows.append(Self.words(field.value)) }
            if field.key == "keys" {
                let words = Self.words(field.value)
                rows.append(words.map(Self.keyCell))
                for word in words where !keys.contains(where: { $0.id == word }) {
                    if let part = Self.keyPart(word) { keys.append(part) }
                }
            }
        }
        let repeats = block.values("repeat").map(Self.words)
        repeated = repeats.first.flatMap { words in words.first.map { (area: $0, perLine: words.count > 1 ? Int(words[1]) ?? 0 : 0) } }
        repeatCount = repeats.count
        if rows.isEmpty, let area = repeated?.area { rows = [[area]] }
        guard !rows.isEmpty else { return nil }
        self.rows = rows
        self.cards = cards
        isDrawn = true
        keyParts = keys
        areas = Self.areas(in: rows)
    }

    /// One column of lines, in the order of the parts. A section with a title starts with a divider, and a section with
    /// no title is only a divider.
    public init(flat parts: [SpotPart]) {
        var rows: [[String]] = []
        for part in parts {
            if part.isSection, !rows.isEmpty { rows.append([Self.divider]) }
            if part.isSection, part.title == nil, part.press == .none, part.control == .none { continue }
            rows.append([part.id])
        }
        self.rows = rows
        cards = []
        isDrawn = false
        keyParts = []
        areas = Self.areas(in: rows)
        repeated = nil
        repeatCount = 0
    }

    /// The letter a part stands on: the letter it names, or in one column its own id.
    public func letter(of part: SpotPart) -> String? {
        isDrawn ? part.cell : part.id
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
            .init(key: "part", value: word),
            .init(key: "cell", value: keyCell(word)),
            .init(key: "title", value: word),
            .init(key: "look", value: "key"),
            .init(key: "press", value: "true")
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
