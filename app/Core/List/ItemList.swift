import Foundation

public struct ItemList: Equatable, Sendable {
    public static let recentLimit = 100
    nonisolated(unsafe) static var findTap: (@Sendable (Bool) -> Void)?

    public private(set) var search: ItemSearch
    public private(set) var query = ""
    public private(set) var recent: [String]
    private(set) var weights: PickWeights
    public private(set) var shown: [SpotItem] = []
    private var topCount = 0
    private var bottomCount = 0
    public private(set) var hasFiles = false
    public private(set) var selected = 0
    public private(set) var perLine = 1
    public private(set) var drawing = RepeatDrawing.list
    public private(set) var isWaiting = false
    public private(set) var landedSearches = 0
    private var awaitsLanding = false
    public private(set) var isFinding = false
    public private(set) var isLoading = false
    public private(set) var hasFailed = false
    private(set) var all: [SpotItem]
    private(set) var searchIndex = SearchIndex()
    private var pinnedAbove: [SpotItem] = []
    private var pinnedBelow: [SpotItem] = []
    private var holdsFiles = false
    private var narrowings: [Narrowing] = []

    fileprivate struct Narrowing: Equatable, Sendable {
        let query: SearchQuery
        let matches: [Int]
    }

    public init(items: [SpotItem] = [], recent: [String] = [], search: ItemSearch = .local) {
        self.search = search
        all = items
        self.recent = recent
        weights = PickWeights(recent)
        reindex()
        refresh()
    }

    public var holdsItems: Bool {
        !all.isEmpty
    }

    public func findsSameRows(as other: ItemList) -> Bool {
        all == other.all && recent == other.recent && search == other.search
    }

    public var selectedItem: SpotItem? {
        shown.indices.contains(selected) ? shown[selected] : nil
    }

    @discardableResult
    public mutating func search(_ text: String) -> Bool {
        guard text != query, search != .off else { return false }
        begin(text)
        return true
    }

    @discardableResult
    public mutating func beginFinding(_ text: String) -> Bool {
        guard text != query, search == .local else { return false }
        query = text
        isFinding = true
        return true
    }

    public mutating func landFinding() {
        guard isFinding else { return }
        isFinding = false
        refresh()
        selected = 0
        landedSearches += 1
    }

    public func found() -> Found {
        Self.findTap?(Thread.isMainThread)
        return Found(query: query, base: all, recent: recent, narrowings: narrowed())
    }

    public mutating func take(_ found: Found) {
        guard isFinding, found.query == query else { return }
        isFinding = false
        if found.base == all, found.recent == recent, search == .local {
            narrowings = found.narrowings
            show(narrowings.last?.matches ?? [])
        } else {
            refresh()
        }
        selected = 0
        landedSearches += 1
    }

    public struct Found: Sendable {
        fileprivate let query: String
        fileprivate let base: [SpotItem]
        fileprivate let recent: [String]
        fileprivate let narrowings: [Narrowing]
    }

    public func differsOnlyInText(from other: ItemList) -> Bool {
        var same = self
        same.query = other.query
        same.selected = other.selected
        same.isFinding = other.isFinding
        return same == other
    }

    public mutating func selectFirst() {
        selected = 0
    }

    private mutating func begin(_ text: String) {
        query = text
        selected = 0
        isFinding = false
        isWaiting = search == .script
        refresh()
        awaitsLanding = isWaiting
        if !isWaiting { landedSearches += 1 }
    }

    public mutating func take(search: ItemSearch) {
        guard search != self.search else { return }
        self.search = search
        reindex()
        isWaiting = search == .script && !query.isEmpty
        refresh()
    }

    public mutating func answer(_ items: [SpotItem], to text: String) {
        guard text == query else { return }
        isWaiting = false
        replace(items)
        if awaitsLanding { landedSearches += 1 }
        awaitsLanding = false
    }

    public mutating func stopWaiting(for text: String) {
        if text == query { isWaiting = false }
    }

    public mutating func beginLoading() {
        isLoading = true
        hasFailed = false
    }

    public mutating func stopLoading() {
        isLoading = false
    }

    public mutating func loadFailed() {
        isLoading = false
        hasFailed = true
    }

    public struct Rows: Sendable {
        fileprivate let items: [SpotItem]
        fileprivate let base: [SpotItem]
        fileprivate let search: ItemSearch
        fileprivate let index: SearchIndex?
    }

    public func ready(_ items: [SpotItem], search: ItemSearch) -> Rows {
        guard items != all else { return Rows(items: all, base: all, search: search, index: nil) }
        return Rows(items: items, base: all, search: search, index: search == .local ? SearchIndex(items) : SearchIndex())
    }

    public mutating func replace(_ items: [SpotItem]) {
        replace(ready(items, search: search))
    }

    public mutating func replace(_ rows: Rows) {
        guard rows.base == all, rows.search == search else { return replace(ready(rows.items, search: search)) }
        let run = selectedItem?.run
        isLoading = false
        hasFailed = false
        if let index = rows.index {
            all = rows.items
            searchIndex = index
            pin()
            narrowings = []
            refresh()
        }
        guard selected > 0 else { return }
        selected = shown.firstIndex { $0.run == run } ?? min(selected, max(shown.count - 1, 0))
    }

    public mutating func select(run: String) {
        landFinding()
        selected = shown.firstIndex { $0.run == run } ?? selected
    }

    public var setsApart: Bool {
        perLine == 1 && bottomCount > 0 && shown.count > topCount + bottomCount
    }

    public var pinnedTop: ArraySlice<SpotItem> {
        shown[..<topCount]
    }

    public var pinnedBottom: ArraySlice<SpotItem> {
        shown[(shown.count - bottomCount)...]
    }

    public var scrolling: ArraySlice<SpotItem> {
        shown[topCount..<(shown.count - bottomCount)]
    }

    public mutating func moveToEdge(last: Bool) {
        landFinding()
        selected = last ? max(shown.count - 1, 0) : 0
    }

    public mutating func move(by step: Int) {
        landFinding()
        selected = min(max(selected + step, 0), max(shown.count - 1, 0))
    }

    public mutating func take(perLine: Int) {
        self.perLine = max(perLine, 1)
    }

    public mutating func take(drawing: RepeatDrawing) {
        self.drawing = drawing
        perLine = drawing.perLine ?? drawing.places.count
    }

    public var isBento: Bool {
        drawing.perLine == nil
    }

    public var isOnLastLine: Bool {
        shown.isEmpty || selected / perLine == (shown.count - 1) / perLine
    }

    public mutating func moveLine(by lines: Int) {
        landFinding()
        let target = selected + lines * perLine
        guard target >= 0, !shown.isEmpty else { return }
        let lastLine = (shown.count - 1) / perLine
        guard target < shown.count || selected / perLine < lastLine else { return }
        selected = min(target, shown.count - 1)
    }

    public mutating func remember(_ item: SpotItem) {
        recent = Array(([item.run] + recent).prefix(Self.recentLimit))
        weights = PickWeights(recent)
        narrowings = []
        refresh()
    }

    private mutating func reindex() {
        searchIndex = search == .local ? SearchIndex(all) : SearchIndex()
        pin()
    }

    private mutating func pin() {
        pinnedAbove = all.filter { $0.pin == .top }
        pinnedBelow = all.filter { $0.pin == .bottom }
        holdsFiles = all.contains { $0.file != nil }
    }

    private mutating func refresh() {
        guard search == .local else {
            narrowings = []
            return show(all.indices)
        }
        narrowings = narrowed()
        show(narrowings.last?.matches ?? [])
    }

    private func narrowed() -> [Narrowing] {
        var narrowings = narrowings
        let next = SearchQuery(text: query)
        while let last = narrowings.last, !next.text.hasPrefix(last.query.text) { narrowings.removeLast() }
        if narrowings.last?.query.text != next.text {
            let among = narrowings.last.flatMap { $0.query.narrows(to: next) ? $0.matches : nil } ?? Array(all.indices)
            narrowings.append(Narrowing(query: next, matches: next.ranking(searchIndex, items: all, among: among, weights: weights)))
        }
        return narrowings
    }

    private mutating func show<Offsets: Collection<Int>>(_ found: Offsets) {
        var rows = pinnedAbove
        rows.reserveCapacity(pinnedAbove.count + found.count + pinnedBelow.count)
        for offset in found where all[offset].pin == nil { rows.append(all[offset]) }
        rows += pinnedBelow
        shown = rows
        topCount = pinnedAbove.count
        bottomCount = pinnedBelow.count
        hasFiles = holdsFiles && rows.contains { $0.file != nil }
    }
}
