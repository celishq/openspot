import Foundation

struct MainSearch {
    private struct Kept {
        let query: SearchQuery
        let items: [SpotItem]
        let texts: SearchIndex
        let search: ItemSearch
        let recent: [String]
        let matches: [Int]

        func matches(of next: SearchQuery, in list: ItemList) -> [Int]? {
            guard list.all == items, list.search == search, list.recent == recent, query == next || query.narrows(to: next) else { return nil }
            return matches
        }
    }

    private var kept: [Kept] = []
    private(set) var rankedCount = 0
    private(set) var indexBuilds = 0

    mutating func matching(_ query: SearchQuery, in lists: [ItemList], unpickedLimit: Int = .max, limit: Int = .max) -> [(list: Int, item: SpotItem)] {
        rankedCount = 0
        let last = kept
        kept = []
        return lists.enumerated()
            .flatMap { index, list in
                let before = last.indices.contains(index) ? last[index] : nil
                let texts = texts(of: list, before: before)
                let count = min(limit, index > 0 && list.recent.isEmpty ? unpickedLimit : .max)
                let among = before?.matches(of: query, in: list)
                let offsets = among ?? Array(list.all.indices)
                rankedCount += offsets.count
                let matches = query.ranked(texts, items: list.all, among: offsets, weights: list.weights)
                kept.append(Kept(query: query, items: list.all, texts: texts, search: list.search, recent: list.recent, matches: matches.map(\.offset)))
                return SearchQuery.best(matches, count: count).map { (list: index, match: $0) }
            }
            .sorted { first, second in
                let one = first.match, two = second.match
                return (one.rank, -one.weight, first.list, one.offset) < (two.rank, -two.weight, second.list, two.offset)
            }
            .prefix(limit)
            .map { (list: $0.list, item: lists[$0.list].all[$0.match.offset]) }
    }

    private mutating func texts(of list: ItemList, before: Kept?) -> SearchIndex {
        guard list.search == .script else { return list.searchIndex }
        if let before, before.search == .script, before.items == list.all { return before.texts }
        indexBuilds += 1
        return SearchIndex(list.all)
    }
}
