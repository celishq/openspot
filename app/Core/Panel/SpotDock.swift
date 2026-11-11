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

    /// The spots that the store shows: all, or those of one origin. The groups of the store show the state.
    public enum Filter: CaseIterable, Equatable, Sendable {
        case all, core, mine

        public var title: String {
            switch self {
            case .all: "All"
            case .core: "Core"
            case .mine: "Mine"
            }
        }

        public func keeps(_ item: Item) -> Bool {
            switch self {
            case .all: true
            case .core: item.origin == .core
            case .mine: item.origin == .mine
            }
        }
    }

    /// The title of the shown spots of one state, the number of them, and the top of its band in the rows.
    public struct Group: Equatable, Sendable {
        public let state: State
        public let count: Int
        public let top: CGFloat
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

    /// The spots that the filter keeps and whose name, or the words under it, hold the search: off, then in search only,
    /// then on the grid, each by name.
    public var shown: [Item] {
        let kept = items.filter { item in
            filter.keeps(item) && (query.isEmpty || [item.command.name, item.command.subtitle ?? ""].contains { $0.localizedStandardContains(query) })
        }
        return Self.states.flatMap { state in kept.filter { $0.state == state } }
    }

    private static let states: [State] = [.off, .searchOnly, .onGrid]

    /// The titles of the groups of the shown spots, while more than one state has spots.
    public func groups(columns: Int) -> [Group] {
        layout(columns: columns).groups
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

    /// A part of a card in the store that a pointer can be over: the Add of a spot that is not on the grid, the cross that
    /// deletes a spot of the plugins folder that is off, or the rest of the card.
    public enum Part: Equatable, Sendable {
        case add, delete, card
    }

    /// The shown spot and the part of its card under a point of the rows, if any.
    public func part(at point: CGPoint, columns: Int) -> (id: String, part: Part)? {
        let rects = rects(columns: columns)
        guard let index = rects.firstIndex(where: { $0.contains(point) }) else { return nil }
        let item = shown[index], rect = rects[index]
        let rim = SpotTokens.corner(for: item.size) * SpotTokens.rimPoint
        if item.state != .onGrid, Self.addRect(in: rect, size: item.size).insetBy(dx: -2, dy: -2).contains(point) { return (item.id, .add) }
        if item.isOwn, item.state == .off, hypot(point.x - rect.maxX + rim, point.y - rect.minY - rim) <= SpotTokens.keycap / 2 + 2 { return (item.id, .delete) }
        return (item.id, .card)
    }

    /// Where the Add of a card lies: a pill on the line under its name, or a round mark on the top left rim of a 1x1 card,
    /// which has no room for words.
    public static func addRect(in rect: CGRect, size: SpotSize) -> CGRect {
        guard size != .small else {
            let rim = SpotTokens.corner(for: size) * SpotTokens.rimPoint
            return CGRect(x: rect.minX + rim - SpotTokens.keycap / 2, y: rect.minY + rim - SpotTokens.keycap / 2, width: SpotTokens.keycap, height: SpotTokens.keycap)
        }
        let words = SpotTokens.nameHeight + 1 + SpotTokens.addHeight
        guard size.rows == 1 else {
            return CGRect(x: rect.minX + SpotTokens.padding, y: rect.maxY - SpotTokens.padding - SpotTokens.addHeight, width: SpotTokens.addWidth, height: SpotTokens.addHeight)
        }
        let x = rect.minX + SpotTokens.padding + SpotTokens.glyphSize + SpotTokens.padding - 5
        return CGRect(x: x, y: rect.minY + (rect.height - words) / 2 + SpotTokens.nameHeight + 1, width: SpotTokens.addWidth, height: SpotTokens.addHeight)
    }

    /// The height of the rows that hold the shown spots, and of the sheet of the opened spot.
    public func height(columns: Int) -> CGFloat {
        (rects(columns: columns).map(\.maxY) + [sheetRect(columns: columns)?.maxY].compactMap { $0 }).max() ?? 0
    }

    private func closedRects(columns: Int) -> [CGRect] {
        layout(columns: columns).rects
    }

    /// The rect of each shown spot with no sheet open, and the title of each group: each state packs its own shelves, under
    /// its title band while more than one state has spots.
    private func layout(columns: Int) -> (rects: [CGRect], groups: [Group]) {
        let parts = Self.states.map { state in shown.filter { $0.state == state } }.filter { !$0.isEmpty }
        let titled = parts.count > 1
        var rects: [CGRect] = [], groups: [Group] = [], top: CGFloat = 0
        for part in parts {
            let start = top + (titled ? SpotTokens.groupTitleBand : 0)
            let packed = places(of: part, columns: columns).map { place in
                CGRect(
                    x: CGFloat(place.column) * (SpotTokens.cell + SpotTokens.columnGap),
                    y: start + CGFloat(place.row) * (SpotTokens.rowHeight + SpotTokens.rowGap),
                    width: SpotTokens.width(columns: place.size.columns),
                    height: SpotTokens.height(rows: place.size.rows)
                )
            }
            if titled, let state = part.first?.state { groups.append(Group(state: state, count: part.count, top: top)) }
            rects += packed
            top = (packed.map(\.maxY).max() ?? start) + SpotTokens.rowGap
        }
        return (rects, groups)
    }

    /// The top of the sheet: a gap under the lowest card that starts no lower than the opened card.
    private func sheetTop(in rects: [CGRect]) -> CGFloat? {
        guard let opened, let index = shown.firstIndex(where: { $0.id == opened }) else { return nil }
        let start = rects[index].minY
        return rects.filter { $0.minY <= start }.map(\.maxY).max().map { $0 + SpotTokens.rowGap }
    }

    /// The row and column of each of these spots, and its size, no wider than the rows. The spots fill shelves in their order:
    /// a shelf is as tall as its first spot, and a later spot no taller moves up into the first place where it fits in
    /// that shelf. No spot grows, and none moves into an earlier shelf.
    private func places(of items: [Item], columns: Int) -> [(row: Int, column: Int, size: SpotSize)] {
        var queue = items.enumerated().map { (index: $0.offset, size: SpotSize(columns: min($0.element.size.columns, columns), rows: $0.element.size.rows)) }
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
