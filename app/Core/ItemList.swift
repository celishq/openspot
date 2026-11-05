import Foundation

/// The items of one list, with the text that searches them, the selected row and the recent picks.
public struct ItemList: Equatable, Sendable {
    public static let recentLimit = 20

    public private(set) var query = ""
    public private(set) var recent: [String]
    public private(set) var shown: [SpotItem] = []
    public private(set) var selected = 0
    private var all: [SpotItem]

    public init(items: [SpotItem] = [], recent: [String] = []) {
        all = items
        self.recent = recent
        refresh()
    }

    public var selectedItem: SpotItem? {
        shown.indices.contains(selected) ? shown[selected] : nil
    }

    public mutating func search(_ text: String) {
        query = text
        selected = 0
        refresh()
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
        shown = SearchQuery(text: query).matching(all, recent: recent)
    }
}
