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
    public private(set) var isWaiting = false
    public private(set) var isLoading = false
    public private(set) var hasFailed = false
    private(set) var all: [SpotItem]
    private(set) var folded: [FoldedItem]
    private var narrowing: Narrowing?

    /// The last search and the indices of its matches, in order, among which a longer search looks.
    private struct Narrowing: Equatable, Sendable {
        let query: SearchQuery
        let matches: [Int]
    }

    public init(items: [SpotItem] = [], recent: [String] = [], search: ItemSearch = .local) {
        self.search = search
        all = items
        folded = items.map(FoldedItem.init)
        self.recent = recent
        refresh()
    }

    /// Whether it holds rows, shown or not.
    public var holdsItems: Bool {
        !all.isEmpty
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

    /// Takes fresh items. A selection at the top stays at the top, and any other stays on its item when it is still there.
    public mutating func replace(_ items: [SpotItem]) {
        let run = selectedItem?.run
        isLoading = false
        hasFailed = false
        all = items
        folded = items.map(FoldedItem.init)
        narrowing = nil
        refresh()
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
        refresh()
    }

    private mutating func refresh() {
        guard search == .local else {
            narrowing = nil
            shown = all
            return
        }
        let next = SearchQuery(text: query)
        let among = narrowing.flatMap { $0.query.narrows(to: next.text) ? $0.matches : nil } ?? Array(folded.indices)
        let ranked = next.ranking(folded, among: among, recent: recent)
        narrowing = Narrowing(query: next, matches: ranked.sorted())
        shown = ranked.map { folded[$0].item }
    }
}
