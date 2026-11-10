import Foundation

/// The items of one list, with the text that searches them, the selected row and the recent picks.
public struct ItemList: Equatable, Sendable {
    public static let recentLimit = 100

    public private(set) var search: ItemSearch
    public private(set) var query = ""
    public private(set) var recent: [String]
    public private(set) var shown: [SpotItem] = []
    public private(set) var selected = 0
    public private(set) var perLine = 1
    /// The drawing that the rows flow through, and the templates that draw them.
    public private(set) var drawing = RepeatDrawing.list
    public private(set) var templates: [String: RowTemplate] = [:]
    public private(set) var isWaiting = false
    public private(set) var isLoading = false
    public private(set) var hasFailed = false
    /// How many list row heights the shown rows take in a list.
    public private(set) var spans = 0
    private(set) var all: [SpotItem]
    /// The searched texts of the rows, for a list that searches them itself. A list that its script searches keeps none.
    private(set) var searchIndex = SearchIndex()
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
        guard text != query else { return false }
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
            narrowings = []
            refresh()
        }
        guard selected > 0 else { return }
        selected = shown.firstIndex { $0.run == run } ?? min(selected, max(shown.count - 1, 0))
    }

    public mutating func select(run: String) {
        selected = shown.firstIndex { $0.run == run } ?? selected
    }

    public mutating func move(by step: Int) {
        selected = min(max(selected + step, 0), max(shown.count - 1, 0))
    }

    /// Takes how many rows go on one line, as the script printed it.
    public mutating func take(perLine: Int) {
        self.perLine = max(perLine, 1)
    }

    /// Takes the drawing and the templates of the rows, as the script printed them. A bento moves by a whole tile on a
    /// line move.
    public mutating func take(drawing: RepeatDrawing, templates: [String: RowTemplate]) {
        self.drawing = drawing
        self.templates = templates
        perLine = drawing.perLine ?? drawing.places.count
        measure()
    }

    /// The template that draws a row: the one it names, or else `template=row`.
    public func template(of item: SpotItem) -> RowTemplate? {
        templates[item.template ?? RowTemplate.defaultName]
    }

    /// How many list row heights a row takes in a list.
    public func span(of item: SpotItem) -> Int {
        template(of: item)?.span ?? 1
    }

    /// Whether the rows flow through a drawing of places of more than one size.
    public var isBento: Bool {
        drawing.perLine == nil
    }

    /// Takes a value that the person set in a slot of a row, so that it shows before the script answers (U10).
    public mutating func set(_ value: String, of slot: String, in run: String) {
        func changed(_ item: SpotItem) -> SpotItem {
            guard item.run == run else { return item }
            return SpotItem(
                title: item.title, subtitle: item.subtitle, run: item.run, symbol: item.symbol, iconFile: item.iconFile, image: item.image,
                glyph: item.glyph, parent: item.parent, hides: item.hides, keywords: item.keywords, shortcut: item.shortcut, isOn: item.isOn, tone: item.tone,
                template: item.template, fields: item.fields.filter { $0.key != slot } + [.init(key: slot, value: value)],
                file: item.file
            )
        }
        all = all.map(changed)
        shown = shown.map(changed)
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
        narrowings = []
        refresh()
    }

    /// Builds the index of the rows when the list searches them itself, and drops it when its script searches them.
    private mutating func reindex() {
        searchIndex = search == .local ? SearchIndex(all) : SearchIndex()
    }

    private mutating func refresh() {
        defer { measure() }
        guard search == .local else {
            narrowings = []
            shown = all
            return
        }
        let next = SearchQuery(text: query)
        while let last = narrowings.last, !next.text.hasPrefix(last.query.text) { narrowings.removeLast() }
        if narrowings.last?.query.text != next.text {
            let among = narrowings.last.flatMap { $0.query.narrows(to: next) ? $0.matches : nil } ?? Array(all.indices)
            narrowings.append(Narrowing(query: next, matches: next.ranking(searchIndex, items: all, among: among, recent: recent)))
        }
        shown = narrowings.last?.matches.map { all[$0] } ?? []
    }

    /// Counts the list row heights of the shown rows, each time the rows or their templates change.
    private mutating func measure() {
        spans = shown.reduce(0) { $0 + span(of: $1) }
    }
}
