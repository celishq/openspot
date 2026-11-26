import Foundation

public struct SearchList<Element> {
    public let all: [Element]
    private let index: SearchIndex

    public init(_ elements: [Element] = [], text: (Element) -> SearchText = { _ in SearchText(title: "") }) {
        all = elements
        index = SearchIndex(elements.map(text))
    }

    public func matching(_ query: SearchQuery) -> [Element] {
        query.ranking(index, among: Array(all.indices)) { _ in 0 }.map { all[$0] }
    }
}

extension SearchList: Sendable where Element: Sendable {}

extension SearchList: Equatable where Element: Equatable {}
