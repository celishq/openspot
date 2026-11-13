import Foundation

/// The items of one list, with the text that searches them, the selected row and the recent picks.
public struct ItemList: Equatable, Sendable {
    public static let recentLimit = 100

    public private(set) var search: ItemSearch
    public private(set) var query = ""
    public private(set) var recent: [String]
    /// The weight of each recent pick, made again only when `recent` changes.
    private(set) var weights: PickWeights
    public private(set) var shown: [SpotItem] = []
    /// How many shown rows are pinned at the top and at the bottom, around the rows that scroll.
    private var topCount = 0
    private var bottomCount = 0
    /// Whether a shown row has a file that a drag can take out.
    public private(set) var hasFiles = false
    public private(set) var selected = 0
    public private(set) var perLine = 1
    /// The drawing that the rows flow through.
    public private(set) var drawing = RepeatDrawing.list
    public private(set) var isWaiting = false
    /// How many searches have shown their rows: a search of the list at once, and a search of its script with its answer.
    public private(set) var landedSearches = 0
    /// Whether the rows of the last search of the script have yet to land.
    private var awaitsLanding = false
    public private(set) var isLoading = false
    public private(set) var hasFailed = false
    private(set) var all: [SpotItem]
    /// The searched texts of the rows, for a list that searches them itself. A list that its script searches keeps none.
    private(set) var searchIndex = SearchIndex()
    /// The rows pinned at the top and at the bottom, and whether any row has a file, found once for each change of the rows.
    private var pinnedAbove: [SpotItem] = []
    private var pinnedBelow: [SpotItem] = []
    private var holdsFiles = false
    /// The searches of the text as it grew, each one a prefix of the next. A longer search looks among the matches of the last
    /// one when it narrows to it, and a shorter one takes its matches back.
    private var narrowings: [Narrowing] = []

    /// A search and the indices of its matches, best first.
    private struct Narrowing: Equatable, Sendable {
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

    /// Whether it holds rows, shown or not.
    public var holdsItems: Bool {
        !all.isEmpty
    }

    /// Whether it holds the same rows, search and state as another list, and differs at most in the selected row.
    public func differsOnlyInSelection(from other: ItemList) -> Bool {
        var same = self
        same.selected = other.selected
        return same == other
    }

    /// Whether a search finds the same rows in it as in another list: the same rows, picks and searcher.
    public func findsSameRows(as other: ItemList) -> Bool {
        all == other.all && recent == other.recent && search == other.search
    }

    public var selectedItem: SpotItem? {
        shown.indices.contains(selected) ? shown[selected] : nil
    }

    /// Searches for new text, and selects the first row. Returns false when the text is the same, and changes nothing.
    @discardableResult
    public mutating func search(_ text: String) -> Bool {
        guard text != query, search != .off else { return false }
        begin(text)
        return true
    }

    /// Selects the first row, and keeps the search.
    public mutating func selectFirst() {
        selected = 0
    }

    private mutating func begin(_ text: String) {
        query = text
        selected = 0
        isWaiting = search == .script
        refresh()
        awaitsLanding = isWaiting
        if !isWaiting { landedSearches += 1 }
    }

    /// Takes who searches this list, as the script printed it. A list that the script now searches waits for its answer.
    public mutating func take(search: ItemSearch) {
        guard search != self.search else { return }
        self.search = search
        reindex()
        isWaiting = search == .script && !query.isEmpty
        refresh()
    }

    /// Takes the answer of a list that the script searches. An answer to an older search is dropped.
    public mutating func answer(_ items: [SpotItem], to text: String) {
        guard text == query else { return }
        isWaiting = false
        replace(items)
        if awaitsLanding { landedSearches += 1 }
        awaitsLanding = false
    }

    /// Stops waiting for the answer to a search, and keeps the rows.
    public mutating func stopWaiting(for text: String) {
        if text == query { isWaiting = false }
    }

    public mutating func beginLoading() {
        isLoading = true
        hasFailed = false
    }

    /// A stopped read changes nothing, so the rows and what the list last said stay.
    public mutating func stopLoading() {
        isLoading = false
    }

    public mutating func loadFailed() {
        isLoading = false
        hasFailed = true
    }

    /// Fresh items made ready for a list: the rows they were compared with, and the index of their searched texts when they
    /// differ from those rows.
    public struct Rows: Sendable {
        fileprivate let items: [SpotItem]
        fileprivate let base: [SpotItem]
        fileprivate let search: ItemSearch
        fileprivate let index: SearchIndex?
    }

    /// Compares fresh items with its rows, and indexes them for this search when they differ. It changes nothing, so that it
    /// can run on any thread while the list goes on.
    public func ready(_ items: [SpotItem], search: ItemSearch) -> Rows {
        guard items != all else { return Rows(items: all, base: all, search: search, index: nil) }
        return Rows(items: items, base: all, search: search, index: search == .local ? SearchIndex(items) : SearchIndex())
    }

    /// Takes fresh items, and folds them only when they differ. A selection at the top stays at the top, and any other stays
    /// on its item when it is still there.
    public mutating func replace(_ items: [SpotItem]) {
        replace(ready(items, search: search))
    }

    /// Takes rows made ready from its own rows, as `replace` takes items. Rows made ready from rows or a search that it no
    /// longer holds are compared again.
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
        selected = shown.firstIndex { $0.run == run } ?? selected
    }

    /// Whether rows pinned at the bottom lie under rows that scroll, so that a thin line sets them apart.
    public var setsApart: Bool {
        perLine == 1 && bottomCount > 0 && shown.count > topCount + bottomCount
    }

    /// The shown rows pinned at the top.
    public var pinnedTop: ArraySlice<SpotItem> {
        shown[..<topCount]
    }

    /// The shown rows pinned at the bottom.
    public var pinnedBottom: ArraySlice<SpotItem> {
        shown[(shown.count - bottomCount)...]
    }

    /// The shown rows between the pinned ones, which scroll.
    public var scrolling: ArraySlice<SpotItem> {
        shown[topCount..<(shown.count - bottomCount)]
    }

    /// Selects the first row, or the last, as ⌘↑ and ⌘↓ do.
    public mutating func moveToEdge(last: Bool) {
        selected = last ? max(shown.count - 1, 0) : 0
    }

    public mutating func move(by step: Int) {
        selected = min(max(selected + step, 0), max(shown.count - 1, 0))
    }

    /// Takes how many rows go on one line, as the script printed it.
    public mutating func take(perLine: Int) {
        self.perLine = max(perLine, 1)
    }

    /// Takes the drawing of the rows, as the script printed it. A bento moves by a whole tile on a line move.
    public mutating func take(drawing: RepeatDrawing) {
        self.drawing = drawing
        perLine = drawing.perLine ?? drawing.places.count
    }

    /// Whether the rows flow through a drawing of places of more than one size.
    public var isBento: Bool {
        drawing.perLine == nil
    }

    /// Whether the selection lies on the last line of the shown rows, or no row shows.
    public var isOnLastLine: Bool {
        shown.isEmpty || selected / perLine == (shown.count - 1) / perLine
    }

    /// Moves to another line and keeps the place in the line. A shorter last line takes its last item, and the first and the
    /// last line stop the move.
    public mutating func moveLine(by lines: Int) {
        let target = selected + lines * perLine
        guard target >= 0, !shown.isEmpty else { return }
        let lastLine = (shown.count - 1) / perLine
        guard target < shown.count || selected / perLine < lastLine else { return }
        selected = min(target, shown.count - 1)
    }

    /// Adds a pick to the front of the recent picks, which keep each pick so that a count of them shows how often.
    public mutating func remember(_ item: SpotItem) {
        recent = Array(([item.run] + recent).prefix(Self.recentLimit))
        weights = PickWeights(recent)
        narrowings = []
        refresh()
    }

    /// Builds the index of the rows when the list searches them itself, and drops it when its script searches them.
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
        let next = SearchQuery(text: query)
        while let last = narrowings.last, !next.text.hasPrefix(last.query.text) { narrowings.removeLast() }
        if narrowings.last?.query.text != next.text {
            let among = narrowings.last.flatMap { $0.query.narrows(to: next) ? $0.matches : nil } ?? Array(all.indices)
            narrowings.append(Narrowing(query: next, matches: next.ranking(searchIndex, items: all, among: among, weights: weights)))
        }
        show(narrowings.last?.matches ?? [])
    }

    /// Shows the found rows between the rows pinned at the top and those pinned at the bottom, so that a search never hides
    /// them.
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
