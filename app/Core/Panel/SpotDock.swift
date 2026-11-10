import Foundation

/// The spots in the dock of Edit Spots: each spot that is off, which the person can turn on or, when it is a file of the
/// plugins folder, delete, and the search that picks the spots that the dock shows.
public struct SpotDock: Equatable, Sendable {
    /// One spot in the dock.
    public struct Item: Identifiable, Equatable, Sendable {
        public let command: Spot
        /// Whether the spot is a file of the plugins folder, which the dock can delete.
        public let isOwn: Bool

        public var id: String {
            command.id
        }

        public init(command: Spot, isOwn: Bool = false) {
            self.command = command
            self.isOwn = isOwn
        }

        /// The size of its card in the dock: one column for a small spot, else two.
        public var size: SpotSize {
            command.size == .small && command.fault == nil ? .small : .wide
        }
    }

    public let items: [Item]
    public var query = ""

    public init(items: [Item]) {
        self.items = items.sorted { $0.command.name.localizedCaseInsensitiveCompare($1.command.name) == .orderedAscending }
    }

    /// The spots whose name, or the words under it, hold the search, by name.
    public var shown: [Item] {
        query.isEmpty ? items : items.filter { item in
            [item.command.name, item.command.subtitle ?? ""].contains { $0.localizedStandardContains(query) }
        }
    }

    /// Where the card of each shown spot lies, in the order of `shown`, from the top left of the first row. The spots fill
    /// rows of this many columns in order, and a spot that does not fit on a row starts the next one.
    public func rects(columns: Int) -> [CGRect] {
        var column = 0
        var row = 0
        return shown.map { item in
            let span = item.size.columns
            if column > 0, column + span > columns {
                column = 0
                row += 1
            }
            defer { column += span }
            let x = CGFloat(column) * (SpotTokens.cell + SpotTokens.columnGap)
            let y = CGFloat(row) * (SpotTokens.dockTileHeight + SpotTokens.rowGap)
            return CGRect(x: x, y: y, width: SpotTokens.width(columns: span), height: SpotTokens.rowHeight)
        }
    }

    /// The height of the rows that hold the shown spots.
    public func height(columns: Int) -> CGFloat {
        rects(columns: columns).last.map { $0.minY + SpotTokens.dockTileHeight } ?? 0
    }
}
