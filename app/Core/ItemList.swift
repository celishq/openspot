import Foundation

/// The items of one list, with the text that searches them, the selected row and the recent picks.
public struct ItemList: Equatable, Sendable {
    public static let recentLimit = 20

    public let search: ItemSearch
    public private(set) var query = ""
    public private(set) var recent: [String]
    public private(set) var shown: [SpotItem] = []
    public private(set) var selected = 0
    public private(set) var isWaiting = false
    public private(set) var isLoading = false
    public private(set) var hasFailed = false
    private(set) var all: [SpotItem]

    public init(items: [SpotItem] = [], recent: [String] = [], search: ItemSearch = .local) {
        self.search = search
        all = items
        self.recent = recent
        refresh()
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
        isWaiting = search == .live
        refresh()
    }

    /// Takes the answer of a live list. An answer to an older search is dropped.
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

    public mutating func remember(_ item: SpotItem) {
        recent = Array(([item.run] + recent.filter { $0 != item.run }).prefix(Self.recentLimit))
        refresh()
    }

    private mutating func refresh() {
        shown = search == .live ? all : SearchQuery(text: query).matching(all, recent: recent)
    }
}
