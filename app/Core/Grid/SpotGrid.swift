import Foundation

/// Packs spots into full rows of four columns. Each spot takes the next shelf, a smaller spot moves up to fill
/// a gap, and spots grow until their shelf has no hole.
public struct SpotGrid: Sendable {
    private typealias Slot = (index: Int, size: SpotSize)

    public init() {}

    public func place(_ sizes: [SpotSize]) -> [SpotPlacement] {
        var queue: [Slot] = sizes.enumerated().map { (index: $0.offset, size: $0.element) }
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

    /// The next size in this list that changes how the grid looks, or nil when none does. The grid can grow a spot to fill
    /// its row, so a step can pass over a size.
    public func nextSize(of index: Int, in sizes: [SpotSize], among choices: [SpotSize]) -> SpotSize? {
        guard sizes.indices.contains(index), !choices.isEmpty else { return nil }
        let now = place(sizes)
        let start = choices.firstIndex(of: sizes[index]) ?? -1
        return (1...choices.count).lazy
            .map { choices[(start + $0 + choices.count) % choices.count] }
            .first { size in
                var next = sizes
                next[index] = size
                return place(next) != now
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
            let there = place(next)[candidate]
            if (there.row, there.column, there.size) != (now.row, now.column, now.size) { return candidate }
            candidate += step
        }
        return nil
    }

    /// Places a square with the spots beside it, and returns the number of rows it used.
    private func placeSquare(_ square: Slot, in queue: inout [Slot], row: Int, placements: inout [SpotPlacement]) -> Int {
        if let next = queue.first, next.size == .square {
            queue.removeFirst()
            placements.append(SpotPlacement(index: square.index, row: row, column: 0, size: .square))
            placements.append(SpotPlacement(index: next.index, row: row, column: 2, size: .square))
            return 2
        }
        let side = taking(nil, from: &queue, room: 4, widest: 2)
        guard !side.isEmpty else {
            placements.append(SpotPlacement(index: square.index, row: row, column: 0, size: .strip))
            return 1
        }
        placements.append(SpotPlacement(index: square.index, row: row, column: 0, size: .square))
        if side.count == 1 {
            placements.append(SpotPlacement(index: side[0].index, row: row, column: 2, size: .square))
            return 2
        }
        var used = [0, 0]
        for spot in justified(side) {
            let line = used[0] + spot.size.columns <= 2 ? 0 : 1
            placements.append(SpotPlacement(index: spot.index, row: row + line, column: 2 + used[line], size: spot.size))
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

    /// Grows spots until they fill the room of four cells.
    private func justified(_ spots: [Slot]) -> [Slot] {
        switch spots.count {
        case 1:
            return [(index: spots[0].index, size: .strip)]
        case 2:
            return spots.map { (index: $0.index, size: .wide) }
        case 3 where spots.allSatisfy({ $0.size == .small }):
            return [(index: spots[0].index, size: .wide)] + spots.dropFirst()
        default:
            return spots
        }
    }
}
