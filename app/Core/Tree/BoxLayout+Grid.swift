import CoreGraphics
import Foundation

extension BoxLayout {
    func grid(_ children: [Child], width: CGFloat?, height given: CGFloat?) -> (CGSize, [CGRect]) {
        let columns = style.columns ?? 1
        let gapX = style.columnGap?.points(of: 0) ?? 0
        let gapY = style.rowGap?.points(of: 0) ?? 0
        let room = width ?? CGFloat(columns) * (children.map { $0.measure(nil, nil).width }.max() ?? 0) + gapX * CGFloat(columns - 1)
        let cell = (room - gapX * CGFloat(columns - 1)) / CGFloat(columns)
        let cells = Self.cells(of: children, columns: columns)
        let widths = children.indices.map { index in
            let span = CGFloat(cells[index].columns)
            let whole = span * cell + (span - 1) * gapX
            return Self.clamped(Self.points(children[index].style.width, of: whole) ?? whole, children[index].style, of: whole)
        }
        let natural = children.indices.map { index in
            let child = children[index]
            return Self.points(child.style.height, of: nil)
                ?? (child.style.isSquare ? widths[index] : child.measure(widths[index], nil).height)
        }
        let rows = cells.map { $0.row + $0.rows }.max() ?? 0
        var heights = Array(repeating: CGFloat(0), count: rows)
        for index in children.indices where cells[index].rows == 1 {
            heights[cells[index].row] = max(heights[cells[index].row], natural[index])
        }
        let spanned = { (place: Cell) in
            heights[place.row..<place.row + place.rows].reduce(0, +) + gapY * CGFloat(place.rows - 1)
        }
        for index in children.indices where cells[index].rows > 1 {
            let short = natural[index] - spanned(cells[index])
            if short > 0 { heights[cells[index].row + cells[index].rows - 1] += short }
        }
        let free = (given ?? 0) - heights.reduce(0, +) - gapY * CGFloat(max(rows - 1, 0))
        if free > 0, rows > 0 { heights = heights.map { $0 + free / CGFloat(rows) } }
        var tops: [CGFloat] = []
        var y: CGFloat = 0
        for height in heights {
            tops.append(y)
            y += height + gapY
        }
        let frames = children.indices.map { index in
            let place = cells[index]
            let tall = spanned(place)
            let alignment = alignment(of: children[index])
            let height = alignment == .stretch && children[index].style.height == nil ? tall : min(natural[index], tall)
            let x = CGFloat(place.column) * (cell + gapX)
            return CGRect(x: x, y: tops[place.row] + Self.offset(alignment, size: height, in: tall), width: widths[index], height: height)
        }
        let height = heights.reduce(0, +) + gapY * CGFloat(max(rows - 1, 0))
        return (CGSize(width: room, height: given ?? height), frames)
    }

    private struct Cell {
        let row: Int
        let column: Int
        let rows: Int
        let columns: Int
    }

    private static func cells(of children: [Child], columns: Int) -> [Cell] {
        var taken: [[Bool]] = []
        var cursor = (row: 0, column: 0)
        var cells: [Cell] = []
        for child in children {
            let wide = min(child.style.columnSpan ?? 1, columns)
            let tall = child.style.rowSpan ?? 1
            var row = cursor.row
            var column = cursor.column
            while true {
                if column + wide > columns {
                    row += 1
                    column = 0
                    continue
                }
                let fits = (row..<row + tall).allSatisfy { y in
                    (column..<column + wide).allSatisfy { x in y >= taken.count || !taken[y][x] }
                }
                if fits { break }
                column += 1
            }
            while taken.count < row + tall { taken.append(Array(repeating: false, count: columns)) }
            for y in row..<row + tall {
                for x in column..<column + wide { taken[y][x] = true }
            }
            cells.append(Cell(row: row, column: column, rows: tall, columns: wide))
            cursor = (row, column + wide)
        }
        return cells
    }
}
