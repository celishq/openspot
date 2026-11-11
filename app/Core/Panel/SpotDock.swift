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

    /// Where the card of each shown spot lies, in the order of `shown`, from the top left of the first row. Each spot, at
    /// its size, takes the first place from the top left where it fits in rows of this many columns, so a smaller spot
    /// moves up into a gap that a larger one left.
    public func rects(columns: Int) -> [CGRect] {
        places(columns: columns).map { place in
            CGRect(
                x: CGFloat(place.column) * (SpotTokens.cell + SpotTokens.columnGap),
                y: CGFloat(place.row) * (SpotTokens.dockTileHeight + SpotTokens.rowGap),
                width: SpotTokens.width(columns: place.size.columns),
                height: SpotTokens.height(rows: place.size.rows)
            )
        }
    }

    /// The height of the rows that hold the shown spots.
    public func height(columns: Int) -> CGFloat {
        let rows = places(columns: columns).map { $0.row + $0.size.rows }.max() ?? 0
        return rows == 0 ? 0 : CGFloat(rows) * SpotTokens.dockTileHeight + CGFloat(rows - 1) * SpotTokens.rowGap
    }

    /// The row and column of each shown spot, and its size, no wider than the rows.
    private func places(columns: Int) -> [(row: Int, column: Int, size: SpotSize)] {
        var taken = Set<[Int]>()
        return shown.map { item in
            let size = SpotSize(columns: min(item.size.columns, columns), rows: item.size.rows)
            var row = 0
            while true {
                let fit = (0...(columns - size.columns)).first { column in
                    (0..<size.rows).allSatisfy { down in (0..<size.columns).allSatisfy { !taken.contains([row + down, column + $0]) } }
                }
                if let column = fit {
                    for down in 0..<size.rows {
                        for across in 0..<size.columns { taken.insert([row + down, column + across]) }
                    }
                    return (row, column, size)
                }
                row += 1
            }
        }
    }
}
