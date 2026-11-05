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
    private var all: [SpotItem]

    public init(items: [SpotItem] = [], recent: [String] = [], search: ItemSearch = .local) {
        self.search = search
        all = items
        self.recent = recent
        refresh()
    }

    public var selectedItem: SpotItem? {
        shown.indices.contains(selected) ? shown[selected] : nil
    }

    /// The items that a search elsewhere finds in this list.
    public func matches(_ text: String) -> [SpotItem] {
        SearchQuery(text: text).matching(all, recent: recent)
    }

    public mutating func search(_ text: String) {
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

    /// Takes fresh items, and keeps the selection on the same item when it is still there.
    public mutating func replace(_ items: [SpotItem]) {
        let run = selectedItem?.run
        all = items
        refresh()
        selected = shown.firstIndex { $0.run == run } ?? min(selected, max(shown.count - 1, 0))
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
