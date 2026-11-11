import Foundation

/// The search of many lists at once that the main search runs on each key. It keeps the matches of the last text in each
/// list, so that a longer text that narrows to it ranks only those. A list whose rows, search or picks changed is ranked
/// whole again.
struct MainSearch {
    /// The matches of one list for one text, with the rows, the search and the picks that they were found in.
    private struct Kept {
        let query: SearchQuery
        let items: [SpotItem]
        let search: ItemSearch
        let recent: [String]
        let matches: [Int]

        /// The offsets that a search for the given text in the given list needs to rank: its matches, when the list is
        /// the same and the text is the same or narrows to it.
        func matches(of next: SearchQuery, in list: ItemList) -> [Int]? {
            guard list.all == items, list.search == search, list.recent == recent, query == next || query.narrows(to: next) else { return nil }
            return matches
        }
    }

    private var kept: [Kept] = []
    /// The number of items that the last search ranked, in all lists.
    private(set) var ranked = 0

    /// The best `limit` items that match in all lists, as one ranking, with the index of the list each came from. Each list
    /// after the first that has no pick gives at most `unpickedLimit` items. Each list keeps only its own best, and only
    /// the items kept are copied out.
    mutating func matching(_ query: SearchQuery, in lists: [ItemList], unpickedLimit: Int = .max, limit: Int = .max) -> [(list: Int, item: SpotItem)] {
        ranked = 0
        let last = kept
        kept = []
        return lists.enumerated()
            .flatMap { index, list in
                let texts = list.search == .local ? list.searchIndex : SearchIndex(list.all)
                let count = min(limit, index > 0 && list.recent.isEmpty ? unpickedLimit : .max)
                let among = last.indices.contains(index) ? last[index].matches(of: query, in: list) : nil
                let offsets = among ?? Array(list.all.indices)
                ranked += offsets.count
                let matches = query.ranked(texts, items: list.all, among: offsets, recent: list.recent)
                kept.append(Kept(query: query, items: list.all, search: list.search, recent: list.recent, matches: matches.map(\.offset)))
                return SearchQuery.best(matches, count: count).map { (list: index, match: $0) }
            }
            .sorted { first, second in
                let one = first.match, two = second.match
                return (one.rank, -one.weight, first.list, one.offset) < (two.rank, -two.weight, second.list, two.offset)
            }
            .prefix(limit)
            .map { (list: $0.list, item: lists[$0.list].all[$0.match.offset]) }
    }
}
