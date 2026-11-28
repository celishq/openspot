import CoreGraphics

/// A block of cells in a grid of `columns` by `rows`, from one corner cell to the opposite one, either way round.
/// Cells count from the top left, as the windows of the Mac count their points.
struct Pick: Equatable {
    let columns: Int
    let rows: Int
    let left: Int
    let top: Int
    let width: Int
    let height: Int

    init(columns: Int, rows: Int, from: (Int, Int), to: (Int, Int)) {
        self.columns = columns
        self.rows = rows
        let first = (min(max(from.0, 0), columns - 1), min(max(from.1, 0), rows - 1))
        let last = (min(max(to.0, 0), columns - 1), min(max(to.1, 0), rows - 1))
        left = min(first.0, last.0)
        top = min(first.1, last.1)
        width = abs(first.0 - last.0) + 1
        height = abs(first.1 - last.1) + 1
    }

    /// The block as `openspot window move` reads it: parts of the usable area of the screen.
    var text: String {
        func part(_ count: Int, _ whole: Int) -> String { count == 0 ? "0" : count == whole ? "1" : "\(count)/\(whole)" }
        return [part(left, columns), part(top, rows), part(width, columns), part(height, rows)].joined(separator: " ")
    }

    /// The frame that `openspot window move` gives a window for this block, in an area whose origin is its top left,
    /// as the windows of the Mac count. Each edge is rounded from the start of the area, by the same parts that `text`
    /// gives the move.
    func frame(in area: CGRect) -> CGRect {
        func part(_ count: Int, _ whole: Int) -> CGFloat { count == whole ? 1 : CGFloat(count) / CGFloat(whole) }
        let (x, width) = Self.span(part(left, columns), part(self.width, columns), area.minX, area.width)
        let (y, height) = Self.span(part(top, rows), part(self.height, rows), area.minY, area.height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func span(_ start: CGFloat, _ length: CGFloat, _ low: CGFloat, _ size: CGFloat) -> (CGFloat, CGFloat) {
        let begin = low + (size * start).rounded()
        return (begin, low + (size * (start + length)).rounded() - begin)
    }

    /// The same frame inside an area whose origin is its bottom left, as AppKit draws.
    func rect(in area: CGRect) -> CGRect {
        let frame = frame(in: CGRect(origin: .zero, size: area.size))
        return CGRect(x: area.minX + frame.minX, y: area.maxY - frame.maxY, width: frame.width, height: frame.height)
    }
}
