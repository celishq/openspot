import Foundation

public struct SpotGrid: Equatable, Sendable {
    private typealias Slot = (index: Int, size: SpotSize, keeps: Bool)

    public let split: Int?
    public let kept: Set<Int>
    public let placed: [Int: GridPanel]
    public let panels: GridPanels

    public init(split: Int? = nil, kept: Set<Int> = [], placed: [Int: GridPanel] = [:], panels: GridPanels = GridPanels()) {
        self.split = split
        self.kept = kept
        self.placed = placed.filter { $0.value != .center }
        self.panels = panels
    }

    public func moving(_ from: Int, to: Int, split: Int?) -> SpotGrid {
        var flags = (0...max(from, to, kept.max() ?? 0, placed.keys.max() ?? 0)).map { (kept.contains($0), placed[$0]) }
        flags.insert(flags.remove(at: from), at: to)
        return SpotGrid(
            split: split,
            kept: Set(flags.indices.filter { flags[$0].0 }),
            placed: Dictionary(uniqueKeysWithValues: flags.indices.compactMap { index in flags[index].1.map { (index, $0) } }),
            panels: panels
        )
    }

    public func keeping(_ index: Int) -> SpotGrid {
        SpotGrid(split: split, kept: kept.union([index]), placed: placed, panels: panels)
    }

    public func placing(_ index: Int, on panel: GridPanel) -> SpotGrid {
        var placed = placed
        placed[index] = panel
        return SpotGrid(split: split, kept: kept, placed: placed, panels: panels)
    }

    public func place(_ sizes: [SpotSize]) -> [SpotPlacement] {
        guard let split, split >= 0, split < sizes.count else { return shelvesByPanel(sizes) }
        let first = shelvesByPanel(Array(sizes[..<split])).map {
            SpotPlacement(index: $0.index, row: $0.row, column: $0.column, size: $0.size, group: .grid)
        }
        let rows = first.map { $0.row + $0.size.rows }.max() ?? 0
        let center = panels.firstColumn(of: .center)
        let second = shelves(Array(sizes[split...]), kept: Set(sizes[split...].indices.map { $0 - split })).map {
            SpotPlacement(index: $0.index + split, row: $0.row + rows, column: $0.column + center, size: $0.size, group: .shelf)
        }
        return first + second
    }

    private func shelvesByPanel(_ sizes: [SpotSize]) -> [SpotPlacement] {
        GridPanel.allCases.flatMap { panel -> [SpotPlacement] in
            let indices = sizes.indices.filter { panels.holding(placed[$0] ?? .center) == panel }
            let local = Set(indices.indices.filter { kept.contains(indices[$0]) })
            let column = panels.firstColumn(of: panel)
            return shelves(indices.map { sizes[$0] }, kept: local).map {
                SpotPlacement(index: indices[$0.index], row: $0.row, column: $0.column + column, size: $0.size)
            }
        }.sorted { $0.index < $1.index }
    }

    public static func height(of placements: [SpotPlacement]) -> CGFloat {
        placements.map(\.rect.maxY).max() ?? 0
    }

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

    private func placeSquare(_ square: Slot, after leading: [Slot] = [], in queue: inout [Slot], row: Int, placements: inout [SpotPlacement]) -> Int {
        if leading.isEmpty, let next = queue.first, next.size == .square {
            queue.removeFirst()
            placements.append(SpotPlacement(index: square.index, row: row, column: 0, size: .square))
            placements.append(SpotPlacement(index: next.index, row: row, column: 2, size: .square))
            return 2
        }
        let panel = leading + taking(nil, from: &queue, room: 4 - leading.reduce(0) { $0 + $1.size.columns }, widest: 2)
        guard !panel.isEmpty else {
            placements.append(SpotPlacement(index: square.index, row: row, column: 0, size: square.keeps ? .square : .strip))
            return square.keeps ? 2 : 1
        }
        let squareColumn = leading.isEmpty ? 0 : 2
        let sideColumn = 2 - squareColumn
        placements.append(SpotPlacement(index: square.index, row: row, column: squareColumn, size: .square))
        if panel.count == 1 {
            placements.append(SpotPlacement(index: panel[0].index, row: row, column: sideColumn, size: panel[0].keeps ? panel[0].size : .square))
            return 2
        }
        var used = [0, 0]
        for spot in justified(panel) {
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
