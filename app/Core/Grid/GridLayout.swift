import Foundation

public struct GridLayout: Equatable, Sendable {
    public let columns: Int
    public let rows: Int

    public init(columns: Int, rows: Int = SpotTokens.rows) {
        self.columns = columns
        self.rows = rows
    }

    public func place(_ spots: [GridSpot], first: Int? = nil) -> [SpotPlacement] {
        var taken = Array(repeating: false, count: columns * rows)
        var placements: [SpotPlacement] = []
        let reading = { (cell: GridCell) in cell.row * columns + cell.column }
        let cells = spots.map { $0.cell.flatMap { holds($0) ? $0 : nil } }
        let held = spots.indices.filter { $0 != first && cells[$0] != nil }
            .sorted { (reading(cells[$0]!), $0) < (reading(cells[$1]!), $1) }
        let loose = spots.indices.filter { $0 != first && cells[$0] == nil }
        for index in (first.map { [$0] } ?? []) + held + loose where spots.indices.contains(index) {
            let spot = spots[index]
            let start = index == first ? spot.cell.map { clamped($0, for: spot.size) } : cells[index]
            guard let cell = freeCell(for: spot.size, from: start.map(reading) ?? 0, in: taken) else { continue }
            mark(cell, spot.size, in: &taken)
            placements.append(SpotPlacement(index: index, row: cell.row, column: cell.column, size: spot.size))
        }
        return placements.sorted { $0.index < $1.index }
    }

    public func size(of size: SpotSize, at cell: GridCell, among others: [SpotPlacement], choices: [SpotSize]) -> SpotSize {
        let taken = occupancy(of: others)
        if fits(size, at: cell, in: taken) { return size }
        guard fits(.small, at: cell, in: taken) else { return size }
        let area = { (size: SpotSize) in size.columns * size.rows }
        return choices
            .filter { area($0) <= area(size) && $0.columns <= size.columns && $0.rows <= size.rows }
            .sorted { (area($0), $0.columns) > (area($1), $1.columns) }
            .first { fits($0, at: cell, in: taken) } ?? size
    }

    public func freeCells(around placements: [SpotPlacement]) -> [GridCell] {
        let taken = occupancy(of: placements)
        return taken.indices.filter { !taken[$0] }.map { GridCell(row: $0 / columns, column: $0 % columns) }
    }

    public func cell(near point: CGPoint, for size: SpotSize) -> GridCell {
        let step = (x: SpotTokens.cell + SpotTokens.columnGap, y: SpotTokens.cell + SpotTokens.rowGap)
        return clamped(GridCell(row: Int((point.y / step.y).rounded()), column: Int((point.x / step.x).rounded())), for: size)
    }

    public func neighbour(of index: Int, in placements: [SpotPlacement], dx: Int, dy: Int) -> Int? {
        guard let here = placements.first(where: { $0.index == index }) else { return nil }
        let isVertical = dy != 0
        let ahead = placements.filter { spot in
            if isVertical {
                return dy > 0 ? spot.row >= here.row + here.size.rows : spot.row + spot.size.rows <= here.row
            }
            let inRow = spot.row < here.row + here.size.rows && here.row < spot.row + spot.size.rows
            return inRow && (dx > 0 ? spot.column >= here.column + here.size.columns : spot.column + spot.size.columns <= here.column)
        }
        func gap(_ spot: SpotPlacement) -> Int {
            if isVertical { return dy > 0 ? spot.row - here.row : here.row - spot.row - spot.size.rows }
            return dx > 0 ? spot.column - here.column : here.column - spot.column - spot.size.columns
        }
        func offset(_ spot: SpotPlacement) -> Int {
            isVertical
                ? abs(2 * spot.column + spot.size.columns - 2 * here.column - here.size.columns)
                : abs(2 * spot.row + spot.size.rows - 2 * here.row - here.size.rows)
        }
        guard let nearest = ahead.map(gap).min() else { return nil }
        return ahead
            .filter { gap($0) == nearest }
            .min { (offset($0), $0.index) < (offset($1), $1.index) }?
            .index
    }

    public func moved(_ index: Int, to cell: GridCell, size: SpotSize, in placements: [SpotPlacement]) -> [SpotPlacement]? {
        var spots = placements.map { GridSpot(size: $0.size, cell: $0.cell) }
        guard spots.indices.contains(index) else { return nil }
        spots[index] = GridSpot(size: size, cell: cell)
        let next = place(spots, first: index)
        return next.count == spots.count ? next : nil
    }

    public var height: CGFloat {
        SpotTokens.height(rows: rows)
    }

    public var width: CGFloat {
        SpotTokens.width(columns: columns)
    }

    private func holds(_ cell: GridCell) -> Bool {
        cell.row < rows && cell.column < columns
    }

    private func clamped(_ cell: GridCell, for size: SpotSize) -> GridCell {
        GridCell(
            row: min(max(cell.row, 0), max(rows - size.rows, 0)),
            column: min(max(cell.column, 0), max(columns - size.columns, 0))
        )
    }

    private func freeCell(for size: SpotSize, from start: Int, in taken: [Bool]) -> GridCell? {
        (start..<taken.count).lazy
            .map { GridCell(row: $0 / columns, column: $0 % columns) }
            .first { fits(size, at: $0, in: taken) }
    }

    private func fits(_ size: SpotSize, at cell: GridCell, in taken: [Bool]) -> Bool {
        guard cell.row >= 0, cell.column >= 0, cell.row + size.rows <= rows, cell.column + size.columns <= columns else { return false }
        for row in cell.row..<(cell.row + size.rows) {
            for column in cell.column..<(cell.column + size.columns) where taken[row * columns + column] { return false }
        }
        return true
    }

    private func mark(_ cell: GridCell, _ size: SpotSize, in taken: inout [Bool]) {
        for row in cell.row..<(cell.row + size.rows) {
            for column in cell.column..<(cell.column + size.columns) { taken[row * columns + column] = true }
        }
    }

    private func occupancy(of placements: [SpotPlacement]) -> [Bool] {
        var taken = Array(repeating: false, count: columns * rows)
        for placement in placements {
            let cell = clamped(GridCell(row: placement.row, column: placement.column), for: placement.size)
            mark(cell, placement.size, in: &taken)
        }
        return taken
    }
}
