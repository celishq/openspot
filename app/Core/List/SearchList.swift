import Foundation

public struct SearchList<Element> {
    private let elements: [Element]
    private let index: SearchIndex

    public init(_ elements: [Element] = [], text: (Element) -> SearchText = { _ in SearchText(title: "") }) {
        self.elements = elements
        index = SearchIndex(elements.map(text))
    }

    public func matching(_ query: SearchQuery) -> [Element] {
        query.ranking(index, among: Array(elements.indices)) { _ in 0 }.map { elements[$0] }
    }
}

extension SearchList: Sendable where Element: Sendable {}
