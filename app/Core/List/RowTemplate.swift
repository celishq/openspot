import Foundation

/// How a row is drawn: the kind of each slot, its drawings by the size of a place, and the keys each row shares (U8). A row
/// fills a slot by its id, and `<slot>.<key>` sets any other key of that slot.
public struct RowTemplate: Equatable, Sendable {
    /// The template of each row that names none.
    public static let defaultName = "row"
    /// The key that each kind of slot takes from `<slot>=<value>`.
    private static let mainKeys = [
        "text": "title", "button": "title", "gauge": "value", "graph": "point", "switch": "on", "slider": "level",
        "field": "text", "choice": "value", "shortcut": "value"
    ]
    private static let pictureKeys = ["symbol", "file", "image", "glyph"]

    public let name: String
    /// Each slot, in the order of its kind line.
    public let slots: [String]
    public let kinds: [String: String]
    /// Each drawing by the size of a place, such as `2x2`. The empty name is the drawing for any place.
    public let drawings: [String: [[String]]]
    private let shared: [String: [TextBlock.Field]]

    /// Reads a `template` block. It needs a name.
    public init?(block: TextBlock) {
        guard let name = block.value("template") else { return nil }
        self.name = name
        var slots: [String] = []
        var kinds: [String: String] = [:]
        var drawings: [String: [[String]]] = [:]
        var shared: [String: [TextBlock.Field]] = [:]
        for field in block.fields.dropFirst() where !field.value.isEmpty {
            if SpotPart.kinds.contains(field.key) {
                slots.append(field.value)
                kinds[field.value] = field.key
            } else if field.key == "grid" || field.key.hasPrefix("grid.") {
                let size = String(field.key.dropFirst(4).drop { $0 == "." })
                drawings[size, default: []].append(field.value.split(whereSeparator: \.isWhitespace).map(String.init))
            } else if let dot = field.key.firstIndex(of: ".") {
                shared[String(field.key[..<dot]), default: []].append(.init(key: String(field.key[field.key.index(after: dot)...]), value: field.value))
            }
        }
        self.slots = slots
        self.kinds = kinds
        self.drawings = drawings
        self.shared = shared
    }

    /// What is wrong with it: a slot that takes the name of a key of a row (U14).
    public var faults: [String] {
        slots.filter(SpotItem.ownKeys.contains).map { "the template \(name) has a slot called \($0), which is a key of a row" }
    }

    /// The drawing for a place of a size such as `2x2`: its own, or else the largest that fits in it, or else the one for any
    /// place, or else one line of the slots in order.
    public func drawing(for size: String = "") -> [[String]] {
        let wanted = Self.cells(size)
        let fitting = drawings.keys.filter { !$0.isEmpty }.compactMap { name in
            Self.cells(name).map { (name: name, cells: $0) }
        }.filter { cells in wanted.map { cells.cells.0 <= $0.0 && cells.cells.1 <= $0.1 } ?? false }
        if let best = fitting.max(by: { $0.cells.0 * $0.cells.1 < $1.cells.0 * $1.cells.1 }), let drawing = drawings[best.name] {
            return drawing
        }
        return drawings[""] ?? [slots]
    }

    /// How many list row heights a row of it takes in a list: one for each two lines of its drawing (U8).
    public var span: Int {
        max(1, (drawing().count + 1) / 2)
    }

    /// The parts that draw a row in this template. A slot that the row hides is left out.
    public func parts(of item: SpotItem) -> [SpotPart] {
        slots.compactMap { slot in
            guard let kind = kinds[slot], item.hides?.contains(slot) != true else { return nil }
            var fields = [TextBlock.Field(key: kind, value: slot)] + (shared[slot] ?? [])
            if kind == "picture" { fields += Self.pictureKeys.compactMap { key in item.picture(key).map { .init(key: key, value: $0) } } }
            if let main = Self.mainKeys[kind], let value = item.value(of: slot) { fields.append(.init(key: main, value: value)) }
            fields += item.keys(of: slot)
            return SpotPart(block: TextBlock(fields: Self.lastWins(fields)))
        }
    }

    /// The fields with only the last value of each key, except `point` and `option`, which repeat.
    private static func lastWins(_ fields: [TextBlock.Field]) -> [TextBlock.Field] {
        var seen = Set<String>()
        return fields.reversed().filter { field in
            ["point", "option", "color"].contains(field.key) || seen.insert(field.key).inserted
        }.reversed()
    }

    private static func cells(_ size: String) -> (Int, Int)? {
        let numbers = size.split(separator: "x").compactMap { Int($0) }
        return numbers.count == 2 ? (numbers[0], numbers[1]) : nil
    }
}
