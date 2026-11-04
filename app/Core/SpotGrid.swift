import Foundation

/// Packs spots into full rows of four columns. Each spot takes the next shelf, a smaller spot moves up to fill
/// a gap, and spots grow until their shelf has no hole.
public struct SpotGrid: Sendable {
    private typealias Spot = (index: Int, size: SpotSize)

    public init() {}

    public func place(_ sizes: [SpotSize]) -> [SpotPlacement] {
        var queue: [Spot] = sizes.enumerated().map { (index: $0.offset, size: $0.element) }
        var placements: [SpotPlacement] = []
        var row = 0
        while let first = queue.first {
            queue.removeFirst()
            if first.size == .strip {
                placements.append(SpotPlacement(index: first.index, row: row, column: 0, size: .strip))
                row += 1
            } else if first.size.rows > 1 {
                row += placeSquare(first, in: &queue, row: row, placements: &placements)
            } else {
                placeRow(taking(first, from: &queue, room: 4), row: row, placements: &placements)
                row += 1
            }
        }
        return placements.sorted { $0.index < $1.index }
    }

    /// Places a square with the spots beside it, and returns the number of rows it used.
    private func placeSquare(_ square: Spot, in queue: inout [Spot], row: Int, placements: inout [SpotPlacement]) -> Int {
        if let next = queue.first, next.size == .square {
            queue.removeFirst()
            placements.append(SpotPlacement(index: square.index, row: row, column: 0, size: .square))
            placements.append(SpotPlacement(index: next.index, row: row, column: 2, size: .square))
            return 2
        }
        let side = taking(nil, from: &queue, room: 4)
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

    private func placeRow(_ spots: [Spot], row: Int, placements: inout [SpotPlacement]) {
        var column = 0
        for spot in justified(spots) {
            placements.append(SpotPlacement(index: spot.index, row: row, column: column, size: spot.size))
            column += spot.size.columns
        }
    }

    /// Takes the next one-row spots from the queue, in order, that fit in the room.
    private func taking(_ first: Spot?, from queue: inout [Spot], room: Int) -> [Spot] {
        var taken = first.map { [$0] } ?? []
        var left = room - (first?.size.columns ?? 0)
        var position = 0
        while left > 0, position < queue.count {
            let next = queue[position]
            if next.size.rows == 1, next.size.columns <= left {
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
    private func justified(_ spots: [Spot]) -> [Spot] {
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
