import Foundation

/// Packs spots into full rows of four columns. Each spot takes the next shelf, a smaller spot moves up to fill
/// a gap, and spots grow until their shelf has no hole, save a kept spot, which keeps its size and may leave one. A square
/// lies on the left of its shelf, or on the right when small spots that fit on half a line come before it.
public struct SpotGrid: Equatable, Sendable {
    private typealias Slot = (index: Int, size: SpotSize, keeps: Bool)

    /// Where the second group starts, when the spots lie in two groups, each under a title band.
    public let split: Int?
    /// The indexes of the spots that keep their size.
    public let kept: Set<Int>

    public init(split: Int? = nil, kept: Set<Int> = []) {
        self.split = split
        self.kept = kept
    }

    /// This grid with the spot at `from` moved to `to` in the order, and the second group starting at `split`.
    public func moving(_ from: Int, to: Int, split: Int?) -> SpotGrid {
        var flags = (0...max(from, to, kept.max() ?? 0)).map { kept.contains($0) }
        flags.insert(flags.remove(at: from), at: to)
        return SpotGrid(split: split, kept: Set(flags.indices.filter { flags[$0] }))
    }

    /// This grid with the spot at this index kept too.
    public func keeping(_ index: Int) -> SpotGrid {
        SpotGrid(split: split, kept: kept.union([index]))
    }

    /// Lays out the spots in shelves, as one group, or as two groups when both have spots. The rows count on through both
    /// groups.
    public func place(_ sizes: [SpotSize]) -> [SpotPlacement] {
        guard let split, split > 0, split < sizes.count else { return shelves(sizes, kept: kept) }
        let band = SpotTokens.groupTitleBand
        let first = shelves(Array(sizes[..<split]), kept: kept.filter { $0 < split }).map {
            SpotPlacement(index: $0.index, row: $0.row, column: $0.column, size: $0.size, top: band)
        }
        let rows = first.map { $0.row + $0.size.rows }.max() ?? 0
        let second = shelves(Array(sizes[split...]), kept: Set(kept.filter { $0 >= split }.map { $0 - split })).map {
            SpotPlacement(index: $0.index + split, row: $0.row + rows, column: $0.column, size: $0.size, top: 2 * band)
        }
        return first + second
    }

    /// The height of the cards and the title bands of these placements.
    public static func height(of placements: [SpotPlacement]) -> CGFloat {
        placements.map(\.rect.maxY).max() ?? 0
    }

    /// Lays out the spots of one group. A spot at an index of `kept` never grows.
    private func shelves(_ sizes: [SpotSize], kept: Set<Int>) -> [SpotPlacement] {
        var queue: [Slot] = sizes.enumerated().map { (index: $0.offset, size: $0.element, keeps: kept.contains($0.offset)) }
        var placements: [SpotPlacement] = []
        var row = 0
        while let first = queue.first {
            queue.removeFirst()
            if first.size == .strip {
                placements.append(SpotPlacement(index: first.index, row: row, column: 0, size: .strip))
                row += 1
            } else if first.size == .large {
                placements.append(SpotPlacement(index: first.index, row: row, column: 0, size: .large))
                row += 2
            } else if first.size.rows > 1 {
                row += placeSquare(first, in: &queue, row: row, placements: &placements)
            } else if let position = squarePosition(after: first, in: queue) {
                let leading = [first] + queue[..<position]
                let square = queue[position]
                queue.removeSubrange(...position)
                row += placeSquare(square, after: leading, in: &queue, row: row, placements: &placements)
            } else {
                placeRow(taking(first, from: &queue, room: 4), row: row, placements: &placements)
                row += 1
            }
        }
        return placements.sorted { $0.index < $1.index }
    }

    /// The spot that an arrow key moves to: in the nearest row or column that way, the one most in line with this spot.
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

    /// The next size in this list that changes how the grid looks, or nil when none does. The grid keeps the spot at the size
    /// it takes.
    public func nextSize(of index: Int, in sizes: [SpotSize], among choices: [SpotSize]) -> SpotSize? {
        guard sizes.indices.contains(index), !choices.isEmpty else { return nil }
        let grid = keeping(index)
        let now = grid.place(sizes)
        let start = choices.firstIndex(of: sizes[index]) ?? -1
        return (1...choices.count).lazy
            .map { choices[(start + $0 + choices.count) % choices.count] }
            .first { size in
                var next = sizes
                next[index] = size
                return grid.place(next) != now
            }
    }

    /// The nearest place in the order, this way, that puts the spot somewhere else on the grid, or nil when none does. The
    /// grid can move a spot back to fill a gap, so a step can pass over a place.
    public func nextPlace(of index: Int, in sizes: [SpotSize], step: Int) -> Int? {
        guard sizes.indices.contains(index) else { return nil }
        let now = place(sizes)[index]
        var candidate = index + step
        while sizes.indices.contains(candidate) {
            var next = sizes
            next.insert(next.remove(at: index), at: candidate)
            let there = moving(index, to: candidate, split: split).place(next)[candidate]
            if (there.row, there.column, there.size) != (now.row, now.column, now.size) { return candidate }
            candidate += step
        }
        return nil
    }

    /// Where the next square lies in the queue, when the one-row spots before it, from `first` on, fit on half a line.
    private func squarePosition(after first: Slot, in queue: [Slot]) -> Int? {
        var width = first.size.columns
        for (position, next) in queue.enumerated() {
            guard width <= 2 else { return nil }
            if next.size == .square { return position }
            guard next.size.rows == 1 else { return nil }
            width += next.size.columns
        }
        return nil
    }

    /// Places a square with the spots beside it, and returns the number of rows it used. Spots that come before the square
    /// put it on the right.
    private func placeSquare(_ square: Slot, after leading: [Slot] = [], in queue: inout [Slot], row: Int, placements: inout [SpotPlacement]) -> Int {
        if leading.isEmpty, let next = queue.first, next.size == .square {
            queue.removeFirst()
            placements.append(SpotPlacement(index: square.index, row: row, column: 0, size: .square))
            placements.append(SpotPlacement(index: next.index, row: row, column: 2, size: .square))
            return 2
        }
        let side = leading + taking(nil, from: &queue, room: 4 - leading.reduce(0) { $0 + $1.size.columns }, widest: 2)
        guard !side.isEmpty else {
            placements.append(SpotPlacement(index: square.index, row: row, column: 0, size: square.keeps ? .square : .strip))
            return square.keeps ? 2 : 1
        }
        let squareColumn = leading.isEmpty ? 0 : 2
        let sideColumn = 2 - squareColumn
        placements.append(SpotPlacement(index: square.index, row: row, column: squareColumn, size: .square))
        if side.count == 1 {
            placements.append(SpotPlacement(index: side[0].index, row: row, column: sideColumn, size: side[0].keeps ? side[0].size : .square))
            return 2
        }
        var used = [0, 0]
        for spot in justified(side) {
            let line = used[0] + spot.size.columns <= 2 ? 0 : 1
            placements.append(SpotPlacement(index: spot.index, row: row + line, column: sideColumn + used[line], size: spot.size))
            used[line] += spot.size.columns
        }
        return 2
    }

    private func placeRow(_ spots: [Slot], row: Int, placements: inout [SpotPlacement]) {
        var column = 0
        for spot in justified(spots) {
            placements.append(SpotPlacement(index: spot.index, row: row, column: column, size: spot.size))
            column += spot.size.columns
        }
    }

    /// Takes the next one-row spots from the queue, in order, that fit in the room and are no wider than the limit.
    private func taking(_ first: Slot?, from queue: inout [Slot], room: Int, widest: Int = 4) -> [Slot] {
        var taken = first.map { [$0] } ?? []
        var left = room - (first?.size.columns ?? 0)
        var position = 0
        while left > 0, position < queue.count {
            let next = queue[position]
            if next.size.rows == 1, next.size.columns <= min(left, widest) {
                taken.append(next)
                left -= next.size.columns
                queue.remove(at: position)
            } else {
                position += 1
            }
        }
        return taken
    }

    /// Grows spots that are not kept until they fill the room of four cells, or as near as the kept spots let them.
    private func justified(_ spots: [Slot]) -> [Slot] {
        let grown = { (spot: Slot, size: SpotSize) in spot.keeps ? spot : (index: spot.index, size: size, keeps: false) }
        switch spots.count {
        case 1:
            return [grown(spots[0], .strip)]
        case 2:
            return spots.map { grown($0, .wide) }
        case 3 where spots.allSatisfy({ $0.size == .small }):
            guard let first = spots.firstIndex(where: { !$0.keeps }) else { return spots }
            var spots = spots
            spots[first] = grown(spots[first], .wide)
            return spots
        default:
            return spots
        }
    }
}
