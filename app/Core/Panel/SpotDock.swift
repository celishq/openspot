import Foundation

/// The store of Edit Spots: every spot with its state and its origin, the filter and the search that pick the spots that
/// it shows. The person turns on a spot that is off, and deletes a file of the plugins folder that is off.
public struct SpotDock: Equatable, Sendable {
    /// Whether a spot shows on the grid, only in search, or not at all.
    public enum State: Equatable, Sendable {
        case onGrid, searchOnly, off
    }

    /// Where a spot comes from: the core spots of the app, the plugins folder, or the app's own code.
    public enum Origin: Equatable, Sendable {
        case core, mine, builtIn
    }

    /// Whether the store's package of a spot of the plugins folder holds its files as they are, or older ones.
    public enum Publication: Equatable, Sendable {
        case current, changed
    }

    /// The spots that the store shows: all, those that are on or off, or those of one origin.
    public enum Filter: CaseIterable, Equatable, Sendable {
        case all, on, off, core, mine

        public var title: String {
            switch self {
            case .all: "All"
            case .on: "On"
            case .off: "Off"
            case .core: "Core"
            case .mine: "Mine"
            }
        }

        public func keeps(_ item: Item) -> Bool {
            switch self {
            case .all: true
            case .on: item.state != .off
            case .off: item.state == .off
            case .core: item.origin == .core
            case .mine: item.origin == .mine
            }
        }
    }

    /// One spot in the store.
    public struct Item: Identifiable, Equatable, Sendable {
        public let command: Spot
        public let origin: Origin
        public let state: State
        /// Its package in the store, for a spot of the plugins folder that the person published.
        public let publication: Publication?
        /// The size of its card, as the panel gives it: the preferred size, or else its own. A fault is never 1x1.
        public let size: SpotSize

        public var id: String {
            command.id
        }

        /// Whether the spot is a file of the plugins folder, which the store can delete while it is off.
        public var isOwn: Bool {
            origin == .mine
        }

        public init(command: Spot, origin: Origin = .core, state: State = .off, size: SpotSize? = nil, publication: Publication? = nil) {
            self.command = command
            self.origin = origin
            self.state = state
            self.publication = publication
            let own = size ?? command.size
            self.size = command.fault != nil && own == .small ? .wide : own
        }
    }

    public let items: [Item]
    public var query = ""
    public var filter = Filter.all
    /// The spot whose listing shows in a sheet under its shelf.
    public var opened: String?

    public init(items: [Item]) {
        self.items = items.sorted { $0.command.name.localizedCaseInsensitiveCompare($1.command.name) == .orderedAscending }
    }

    /// The dock with this spot at this size.
    public func resized(_ id: String, to size: SpotSize) -> SpotDock {
        var next = SpotDock(items: items.map { $0.id == id ? Item(command: $0.command, origin: $0.origin, state: $0.state, size: size, publication: $0.publication) : $0 })
        next.query = query
        next.filter = filter
        next.opened = opened
        return next
    }

    /// The spots that the filter keeps and whose name, or the words under it, hold the search, by name.
    public var shown: [Item] {
        items.filter { item in
            filter.keeps(item) && (query.isEmpty || [item.command.name, item.command.subtitle ?? ""].contains { $0.localizedStandardContains(query) })
        }
    }

    /// Where the card of each shown spot lies, in the order of `shown`, from the top left of the first row, with the grid's
    /// gaps. The cards under the sheet of an opened spot lie lower by the sheet and a gap.
    public func rects(columns: Int) -> [CGRect] {
        let rects = closedRects(columns: columns)
        guard let top = sheetTop(in: rects) else { return rects }
        return rects.map { $0.minY < top ? $0 : $0.offsetBy(dx: 0, dy: SpotTokens.storeSheetHeight + SpotTokens.rowGap) }
    }

    /// Where the sheet of the opened spot lies: under the shelf of its card, as wide as the rows.
    public func sheetRect(columns: Int) -> CGRect? {
        sheetTop(in: closedRects(columns: columns)).map { CGRect(x: 0, y: $0, width: SpotTokens.width(columns: columns), height: SpotTokens.storeSheetHeight) }
    }

    /// The height of the rows that hold the shown spots, and of the sheet of the opened spot.
    public func height(columns: Int) -> CGFloat {
        let rows = places(columns: columns).map { $0.row + $0.size.rows }.max() ?? 0
        let sheet = sheetRect(columns: columns) == nil ? 0 : SpotTokens.storeSheetHeight + SpotTokens.rowGap
        return rows == 0 ? 0 : SpotTokens.height(rows: rows) + sheet
    }

    private func closedRects(columns: Int) -> [CGRect] {
        places(columns: columns).map { place in
            CGRect(
                x: CGFloat(place.column) * (SpotTokens.cell + SpotTokens.columnGap),
                y: CGFloat(place.row) * (SpotTokens.rowHeight + SpotTokens.rowGap),
                width: SpotTokens.width(columns: place.size.columns),
                height: SpotTokens.height(rows: place.size.rows)
            )
        }
    }

    /// The top of the sheet: a gap under the lowest card that starts no lower than the opened card.
    private func sheetTop(in rects: [CGRect]) -> CGFloat? {
        guard let opened, let index = shown.firstIndex(where: { $0.id == opened }) else { return nil }
        let start = rects[index].minY
        return rects.filter { $0.minY <= start }.map(\.maxY).max().map { $0 + SpotTokens.rowGap }
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
