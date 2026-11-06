import Foundation

/// Where the parts of a sheet go: a drawing in letters, a drawing the app knows by name, or one column of lines.
public struct SheetLayout: Equatable, Sendable {
    /// A drawing with named cells, which a script asks for with `layout=<name>`.
    public struct Named: Equatable, Sendable {
        public let purpose: String
        public let drawing: [String]
        public let cells: [String: String]
        public let cards: [String]
        public let fills: [String]
    }

    public static let empty = "."
    public static let divider = "-"

    public static let named: [String: Named] = [
        "pair": Named(
            purpose: "Text in, text out: one card, a menu on each side, a swap on the divider, an action in the corner. Both texts fill the height.",
            drawing: ["s s . .", "i i i i", "i i i x", "- - - x", "t t . x", "o o o o", "o o o c"],
            cells: ["from": "s", "top": "i", "swap": "x", "to": "t", "bottom": "o", "action": "c"],
            cards: ["s", "i", "t", "o"],
            fills: ["i", "o"]
        ),
        "media": Named(
            purpose: "A picture with its main action in the corner, a title, a seek bar and two buttons.",
            drawing: ["a a a a", "a a a a", "a a a a", "a a p p", "a a p p", "t t t t", "s s s s", ". b n ."],
            cells: ["picture": "a", "action": "p", "title": "t", "seek": "s", "back": "b", "next": "n"],
            cards: [],
            fills: []
        ),
        "job": Named(
            purpose: "A long task: what it works on, two options, progress, a log that fills the height, and an action in the log's corner.",
            drawing: ["f f f f", "q q r r", "p p p p", "p p p p", "l l l l", "l l l c"],
            cells: ["file": "f", "left": "q", "right": "r", "progress": "p", "log": "l", "action": "c"],
            cards: ["f", "q", "r"],
            fills: ["l"]
        ),
        "chat": Named(
            purpose: "Messages that fill the height, above a field with a control on each side of its last line.",
            drawing: ["m m m m", "i i i i", "i i i i", "a i i s"],
            cells: ["messages": "m", "input": "i", "left": "a", "send": "s"],
            cards: [],
            fills: ["m"]
        ),
        "tiles": Named(
            purpose: "Four numbers around a chart, with a small action in the chart's corner.",
            drawing: ["a a b b", "a a b b", "g g g r", "g g g g", "g g g g", "c c d d", "c c d d"],
            cells: ["one": "a", "two": "b", "chart": "g", "corner": "r", "three": "c", "four": "d"],
            cards: [],
            fills: []
        ),
        "browse": Named(
            purpose: "A list on the left, a preview on the right with an action in its corner, and a line under both.",
            drawing: ["l l d d", "l l d d", "l l d c", "b b b b"],
            cells: ["list": "l", "preview": "d", "action": "c", "bottom": "b"],
            cards: [],
            fills: ["l", "d"]
        )
    ]

    public let rows: [[String]]
    public let cards: [[String]]
    public let cells: [String: String]
    public let fills: Set<String>
    public let name: String?
    public let isDrawn: Bool
    public let keyParts: [SpotPart]
    public let areas: [String: SheetArea]

    /// Reads the layout block of a sheet. Returns nil when the block has no `grid`, `keys` or known `layout`.
    public init?(block: TextBlock) {
        var rows: [[String]] = []
        var keys: [SpotPart] = []
        var cards = block.values("card").map(Self.words)
        let named = block.value("layout").flatMap { Self.named[$0] }
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
        if let named {
            rows = named.drawing.map(Self.words)
            if !named.cards.isEmpty { cards.append(named.cards) }
        }
        guard !rows.isEmpty else { return nil }
        self.rows = rows
        self.cards = cards
        cells = named?.cells ?? [:]
        fills = Set(named?.fills ?? [])
        name = named == nil ? nil : block.value("layout")
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
            for _ in 0..<part.flatRows { rows.append([part.id]) }
        }
        self.rows = rows
        cards = []
        cells = [:]
        fills = []
        name = nil
        isDrawn = false
        keyParts = []
        areas = Self.areas(in: rows)
    }

    /// The letter a part stands on: its named cell, the letter it names, or in one column its own id.
    public func letter(of part: SpotPart) -> String? {
        guard isDrawn else { return part.id }
        guard let cell = part.cell else { return nil }
        return cells[cell] ?? cell
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
