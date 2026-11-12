import Foundation

/// The store of Edit Spots: every spot with its state and its origin, the section and the search that pick the spots that
/// it shows, and the rows that show them, two to a line under the title of their state. Each row ends in the button of its
/// next step and an arrow that opens its menu.
public struct SpotDock: Equatable, Sendable {
    /// Whether a spot shows on the grid, only in search, or is not added.
    public enum State: Equatable, Sendable {
        case onGrid, searchOnly, off
    }

    /// Where a spot comes from: the core spots of the app, the spots folder, or the app's own code.
    public enum Origin: Equatable, Sendable {
        case core, mine, builtIn
    }

    /// Whether the store's package of a spot of the spots folder holds its files as they are, or older ones.
    public enum Publication: Equatable, Sendable {
        case current, changed
    }

    /// The part of the store that the sidebar picks: the spots that are added, those that are not, or the person's own.
    public enum Section: CaseIterable, Equatable, Sendable {
        case added, store, mine

        public var title: String {
            switch self {
            case .added: "Added"
            case .store: "Store"
            case .mine: "Made by You"
            }
        }

        public func keeps(_ item: Item) -> Bool {
            switch self {
            case .added: item.state != .off
            case .store: item.state == .off
            case .mine: item.isOwn
            }
        }
    }

    /// What the main part of a row's button does next: a spot climbs from not added to search to the grid, and a spot of the
    /// person's own with changes publishes them first.
    public enum Step: CaseIterable, Equatable, Sendable {
        case open, add, addToGrid, publish

        public var title: String {
            switch self {
            case .open: "Open"
            case .add: "Add"
            case .addToGrid: "Add to Grid"
            case .publish: "Publish"
            }
        }
    }

    /// What a choice of a row's menu does.
    public enum Action: Equatable, Sendable {
        case place(State), open, publish, share, copyPrompt, edit, moveToTrash
    }

    /// One choice of a row's menu.
    public struct Choice: Equatable, Sendable {
        public let title: String
        public let action: Action
        public var isChecked = false
    }

    /// The title of a group of rows, the number of its spots, and the top of its band.
    public struct Group: Equatable, Sendable {
        public let title: String
        public let count: Int
        public let top: CGFloat
    }

    /// A part of a row that a pointer can be over: the main part of its button, its arrow, or the rest of the row.
    public enum Part: Equatable, Sendable {
        case step, menu, row
    }

    /// One spot in the store.
    public struct Item: Identifiable, Equatable, Sendable {
        public let spot: Spot
        public let origin: Origin
        public let state: State
        /// Its package in the store, for a spot of the spots folder that the person published.
        public let publication: Publication?
        /// The size of its card on the grid, as the panel gives it: the preferred size, or else its own. A fault is never 1x1.
        public let size: SpotSize

        public var id: String {
            spot.id
        }

        /// Whether the spot is a file of the spots folder, which the person can publish and move to the Trash.
        public var isOwn: Bool {
            origin == .mine
        }

        public var step: Step {
            if isOwn, state != .off, publication != .current { return .publish }
            switch state {
            case .off: return .add
            case .searchOnly: return .addToGrid
            case .onGrid: return .open
            }
        }

        public init(spot: Spot, origin: Origin = .core, state: State = .off, size: SpotSize? = nil, publication: Publication? = nil) {
            self.spot = spot
            self.origin = origin
            self.state = state
            self.publication = publication
            let own = size ?? spot.size
            self.size = spot.fault != nil && own == .small ? .wide : own
        }
    }

    public let items: [Item]
    public var query = ""
    public var section = Section.added
    /// The spot whose listing shows in a sheet under its line.
    public var opened: String?
    /// Whether the sheet of the opened spot is out at its whole size, with the later rows pushed down. A sheet starts in,
    /// so that it is built before it grows.
    public var isSheetOut = false

    public init(items: [Item]) {
        self.items = items.sorted { $0.spot.name.localizedCaseInsensitiveCompare($1.spot.name) == .orderedAscending }
    }

    /// Where the rows start in the store, right of the sidebar, which is as wide as the panel's grid.
    public static let rowsOrigin = CGPoint(x: SpotTokens.padding + SpotTokens.gridWidth + SpotTokens.columnGap, y: SpotTokens.dockRowsTop)

    public func count(of section: Section) -> Int {
        items.filter(section.keeps).count
    }

    /// The spots that the section keeps, or with a search the spots of every section whose name or the words under it hold
    /// it, in the order of their groups.
    public var shown: [Item] {
        parts.flatMap(\.items)
    }

    /// The titled groups of the shown spots, each with its spots in order.
    private var parts: [(title: String, items: [Item])] {
        let found = items.filter { item in
            query.isEmpty ? section.keeps(item) : [item.spot.name, item.spot.subtitle ?? ""].contains { $0.localizedStandardContains(query) }
        }
        let byState: [(String, [Item])] = [
            ("On Grid", found.filter { $0.state == .onGrid }), ("In Search", found.filter { $0.state == .searchOnly }), ("Not Added", found.filter { $0.state == .off })
        ]
        let groups = query.isEmpty && section == .mine
            ? [("Not Published", found.filter { $0.publication != .current }), ("Published", found.filter { $0.publication == .current })]
            : byState
        return groups.filter { !$0.1.isEmpty }.map { (title: $0.0, items: $0.1) }
    }

    /// The titles of the groups. The titles under the sheet of an opened spot lie lower by the sheet and a gap.
    public var groups: [Group] {
        let (rects, groups) = layout
        guard isSheetOut, let top = sheetTop(in: rects) else { return groups }
        return groups.map { $0.top < top ? $0 : Group(title: $0.title, count: $0.count, top: $0.top + Self.sheetDrop) }
    }

    /// Where the row of each shown spot lies, in the order of `shown`, from the top left of the rows. The rows under the sheet
    /// of an opened spot lie lower by the sheet and a gap.
    public var rects: [CGRect] {
        let rects = layout.rects
        guard isSheetOut, let top = sheetTop(in: rects) else { return rects }
        return rects.map { $0.minY < top ? $0 : $0.offsetBy(dx: 0, dy: Self.sheetDrop) }
    }

    private static let sheetDrop = SpotTokens.storeSheetHeight + SpotTokens.rowGap

    /// Where the sheet of the opened spot lies: under the line of its row, as wide as the rows.
    public var sheetRect: CGRect? {
        sheetTop(in: layout.rects).map { CGRect(x: 0, y: $0, width: SpotTokens.width(columns: 8), height: SpotTokens.storeSheetHeight) }
    }

    /// The height of the rows that hold the shown spots, and of the sheet of the opened spot while it is out.
    public var height: CGFloat {
        (rects.map(\.maxY) + [isSheetOut ? sheetRect?.maxY : nil].compactMap { $0 }).max() ?? 0
    }

    /// The places in `shown` of the spots whose rows reach into this band of the rows.
    public func shownIndices(within band: ClosedRange<CGFloat>) -> [Int] {
        let rects = rects
        return rects.indices.filter { rects[$0].maxY >= band.lowerBound && rects[$0].minY <= band.upperBound }
    }

    /// The shown spot and the part of its row under a point of the rows, if any.
    public func part(at point: CGPoint) -> (id: String, part: Part)? {
        let rects = rects
        guard let index = rects.firstIndex(where: { $0.contains(point) }) else { return nil }
        let rect = rects[index], id = shown[index].id
        if Self.menuRect(in: rect).contains(point) { return (id, .menu) }
        if Self.stepRect(in: rect).contains(point) { return (id, .step) }
        return (id, .row)
    }

    /// Where the arrow of a row's button lies: at its trailing end, a padding inside the row.
    public static func menuRect(in rect: CGRect) -> CGRect {
        let height = SpotTokens.storeButtonHeight
        return CGRect(x: rect.maxX - SpotTokens.padding - SpotTokens.storeArrowWidth, y: rect.midY - height / 2, width: SpotTokens.storeArrowWidth, height: height)
    }

    /// Where the main part of a row's button lies, before its arrow. Every step has the same width, so the buttons line up.
    public static func stepRect(in rect: CGRect) -> CGRect {
        let arrow = menuRect(in: rect)
        return CGRect(x: arrow.minX - SpotTokens.storeStepWidth, y: arrow.minY, width: SpotTokens.storeStepWidth, height: arrow.height)
    }

    /// The choices of a spot's menu, in parts that lines divide: where it shows, Open while it is added, what the person can
    /// do with it in the store, and the file of a spot of their own. It holds only the choices that can run: a built-in spot
    /// is never off, a package that is current has nothing to publish, and only a spot that is not added goes to the Trash.
    public static func menu(for item: Item) -> [[Choice]] {
        let places: [(State, String)] = [(.onGrid, "On Grid"), (.searchOnly, "In Search Only")] + (item.origin == .builtIn ? [] : [(.off, "Not Added")])
        var parts = [places.map { Choice(title: $0.1, action: .place($0.0), isChecked: item.state == $0.0) }]
        if item.state != .off { parts.append([Choice(title: "Open", action: .open)]) }
        guard item.isOwn else { return parts + [[Choice(title: "Copy Prompt to Review", action: .copyPrompt)]] }
        parts.append(
            (item.publication == .current ? [] : [Choice(title: "Publish", action: .publish)])
                + (item.publication == nil ? [] : [Choice(title: "Share", action: .share)])
                + [Choice(title: "Copy Prompt to Change", action: .copyPrompt)]
        )
        parts.append([Choice(title: "Edit", action: .edit)] + (item.state == .off ? [Choice(title: "Move to Trash", action: .moveToTrash)] : []))
        return parts
    }

    /// The rect of each shown spot with no sheet open, and the title of each group: two rows to a line, each group under its
    /// title band, and each group after the first a gap lower.
    private var layout: (rects: [CGRect], groups: [Group]) {
        var rects: [CGRect] = [], groups: [Group] = [], top: CGFloat = 0
        let line = SpotTokens.rowHeight + SpotTokens.rowGap
        for part in parts {
            if !groups.isEmpty { top += SpotTokens.groupGap }
            groups.append(Group(title: part.title, count: part.items.count, top: top))
            let start = top + SpotTokens.groupTitleBand
            rects += part.items.indices.map { index in
                CGRect(x: CGFloat(index % 2) * (SpotTokens.gridWidth + SpotTokens.columnGap), y: start + CGFloat(index / 2) * line, width: SpotTokens.gridWidth, height: SpotTokens.rowHeight)
            }
            top = start + CGFloat((part.items.count + 1) / 2) * line
        }
        return (rects, groups)
    }

    /// The top of the sheet: a gap under the line of the opened row.
    private func sheetTop(in rects: [CGRect]) -> CGFloat? {
        guard let opened, let index = shown.firstIndex(where: { $0.id == opened }) else { return nil }
        return rects[index].maxY + SpotTokens.rowGap
    }
}
