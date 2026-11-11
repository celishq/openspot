import Foundation

/// The spots in the dock of Edit Spots: each spot that is off, which the person can turn on or, when it is a file of the
/// plugins folder, delete, and the search that picks the spots that the dock shows.
public struct SpotDock: Equatable, Sendable {
    /// One spot in the dock.
    public struct Item: Identifiable, Equatable, Sendable {
        public let spot: Spot
        /// Whether the spot is a file of the plugins folder, which the dock can delete.
        public let isOwn: Bool
        /// The size of its card, as the panel gives it: the preferred size, or else its own. A fault is never 1x1.
        public let size: SpotSize

        public var id: String {
            spot.id
        }

        public init(spot: Spot, isOwn: Bool = false, size: SpotSize? = nil) {
            self.spot = spot
            self.isOwn = isOwn
            let own = size ?? spot.size
            self.size = spot.fault != nil && own == .small ? .wide : own
        }
    }

    public let items: [Item]
    public var query = ""

    public init(items: [Item]) {
        self.items = items.sorted { $0.spot.name.localizedCaseInsensitiveCompare($1.spot.name) == .orderedAscending }
    }

    /// The dock with this spot at this size.
    public func resized(_ id: String, to size: SpotSize) -> SpotDock {
        var next = SpotDock(items: items.map { $0.id == id ? Item(spot: $0.spot, isOwn: $0.isOwn, size: size) : $0 })
        next.query = query
        return next
    }

    /// The spots whose name, or the words under it, hold the search, by name.
    public var shown: [Item] {
        query.isEmpty ? items : items.filter { item in
            [item.spot.name, item.spot.subtitle ?? ""].contains { $0.localizedStandardContains(query) }
        }
    }

    /// Where the card of each shown spot lies, in the order of `shown`, from the top left of the first row, with the grid's
    /// gaps.
    public func rects(columns: Int) -> [CGRect] {
        places(columns: columns).map { place in
            CGRect(
                x: CGFloat(place.column) * (SpotTokens.cell + SpotTokens.columnGap),
                y: CGFloat(place.row) * (SpotTokens.rowHeight + SpotTokens.rowGap),
                width: SpotTokens.width(columns: place.size.columns),
                height: SpotTokens.height(rows: place.size.rows)
            )
        }
    }

    /// The height of the rows that hold the shown spots.
    public func height(columns: Int) -> CGFloat {
        let rows = places(columns: columns).map { $0.row + $0.size.rows }.max() ?? 0
        return rows == 0 ? 0 : SpotTokens.height(rows: rows)
    }

    /// The row and column of each shown spot, and its size, no wider than the rows. The spots fill shelves in their order:
    /// a shelf is as tall as its first spot, and a later spot no taller moves up into the first place where it fits in
    /// that shelf. No spot grows, and none moves into an earlier shelf.
    private func places(columns: Int) -> [(row: Int, column: Int, size: SpotSize)] {
        var queue = shown.enumerated().map { (index: $0.offset, size: SpotSize(columns: min($0.element.size.columns, columns), rows: $0.element.size.rows)) }
        var places = [(row: Int, column: Int, size: SpotSize)?](repeating: nil, count: queue.count)
        var row = 0
        while let first = queue.first {
            var taken = Set<[Int]>()
            var position = 0
            while position < queue.count {
                let spot = queue[position]
                let fit = spot.size.rows > first.size.rows ? nil : (0...(columns - spot.size.columns)).lazy.flatMap { column in
                    (0...(first.size.rows - spot.size.rows)).lazy.map { down in [down, column] }
                }.first { cell in
                    (0..<spot.size.rows).allSatisfy { down in (0..<spot.size.columns).allSatisfy { !taken.contains([cell[0] + down, cell[1] + $0]) } }
                }
                guard let cell = fit else {
                    position += 1
                    continue
                }
                for down in 0..<spot.size.rows {
                    for across in 0..<spot.size.columns { taken.insert([cell[0] + down, cell[1] + across]) }
                }
                places[spot.index] = (row + cell[0], cell[1], spot.size)
                queue.remove(at: position)
            }
            row += first.size.rows
        }
        return places.compactMap { $0 }
    }
}
