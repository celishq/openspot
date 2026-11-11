import Foundation

/// The drawing of a repeat: the places of one tile, in the order in which rows take them (U7). The tile repeats down for as
/// long as there are rows, so `grid=a` is a list, `grid=a b c` is a grid of three to a line, and a drawing with larger places
/// is a bento.
public struct RepeatDrawing: Equatable, Sendable {
    public let columns: Int
    /// How many lines one tile has.
    public let lines: Int
    public let places: [SheetArea]

    /// One place across the whole width: a list.
    public static let list = RepeatDrawing(lines: [["a"]])

    public init(lines drawing: [[String]]) {
        var order: [String] = []
        var areas: [String: SheetArea] = [:]
        for (y, line) in drawing.enumerated() {
            for (x, word) in line.enumerated() where word != SheetLayout.empty {
                let cell = SheetArea(x0: x, x1: x, y0: y, y1: y)
                if areas[word] == nil { order.append(word) }
                areas[word] = areas[word]?.joined(cell) ?? cell
            }
        }
        let places = order.compactMap { areas[$0] }
        self.places = places.isEmpty ? [SheetArea(x0: 0, x1: 0, y0: 0, y1: 0)] : places
        columns = max(drawing.map(\.count).max() ?? 1, 1)
        lines = max(drawing.count, 1)
    }

    /// Reads the `grid` lines of a `repeat` block. With none, it is a list.
    public init(block: TextBlock) {
        let drawing = block.values("grid").map { $0.split(whereSeparator: \.isWhitespace).map(String.init) }
        self = drawing.isEmpty ? .list : RepeatDrawing(lines: drawing)
    }

    /// How many rows go on one line, when each place is one cell of one line. A bento has none.
    public var perLine: Int? {
        lines == 1 && places.allSatisfy { $0.size == 1 } ? places.count : nil
    }

    /// The cells that the row at an index covers, counted from the top of the first tile.
    public func area(of index: Int) -> SheetArea {
        let tile = index / places.count
        var area = places[index % places.count]
        area.y0 += tile * lines
        area.y1 += tile * lines
        return area
    }

    /// How many lines of cells a number of rows fills.
    public func lineCount(rows: Int) -> Int {
        guard rows > 0 else { return 0 }
        let full = (rows - 1) / places.count
        let last = places.prefix((rows - 1) % places.count + 1).map(\.y1).max() ?? 0
        return full * lines + last + 1
    }
}
