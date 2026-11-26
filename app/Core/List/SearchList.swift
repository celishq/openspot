import Foundation

public struct SearchList<Element> {
    private let elements: [Element]
    private let items: [SpotItem]
    private let index: SearchIndex

    public init() {
        self.init([]) { _ in ("", nil, []) }
    }

    public init(_ elements: [Element], text: (Element) -> (title: String, subtitle: String?, keywords: [String])) {
        self.elements = elements
        items = elements.enumerated().map { offset, element in
            let words = text(element)
            return SpotItem(title: words.title, subtitle: words.subtitle, run: String(offset), keywords: words.keywords)
        }
        index = SearchIndex(items)
    }

    public func matching(_ query: SearchQuery) -> [Element] {
        query.ranking(index, items: items, among: Array(items.indices), weights: PickWeights([])).map { elements[$0] }
    }

    public func matching(_ text: String) -> [Element] {
        matching(SearchQuery(text: text))
    }
}

extension SearchList: Sendable where Element: Sendable {}
