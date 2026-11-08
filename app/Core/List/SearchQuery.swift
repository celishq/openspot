import Foundation

/// Text that finds and ranks items. The glyph and the whole title rank first, then the title start. Otherwise each word
/// must match, and the worst word sets the rank: a word start, the initials, any part of the title, a keyword start, a word
/// start of the subtitle, any part of the subtitle, then three or more letters in order in one word of the title. Within a
/// rank, picked items come first, the most picked before the latest, then the given order. Across lists, a pick beats any
/// other item of its rank, then an earlier list wins.
public struct SearchQuery: Equatable, Sendable {
    public let text: String
    private let letters: [UInt64]
    private let words: [[UInt64]]

    public init(text: String) {
        self.text = text.trimmingCharacters(in: .whitespaces)
        letters = self.text.map(FoldedText.code)
        words = self.text.split(whereSeparator: \.isWhitespace).map { $0.map(FoldedText.code) }
    }

    /// The letters of the item that this text matches. An item that does not match has none.
    public func marks(in item: SpotItem) -> SearchMarks {
        match(FoldedItem(item))?.marks ?? SearchMarks(title: [], subtitle: [])
    }

    public func matching(_ items: [SpotItem], recent: [String] = []) -> [SpotItem] {
        matching(items.map(FoldedItem.init), recent: recent)
    }

    func matching(_ items: [FoldedItem], recent: [String] = []) -> [SpotItem] {
        ranking(items, among: Array(items.indices), recent: recent).map { items[$0].item }
    }

    /// The indices of the items among the given ones that match, best first.
    func ranking(_ items: [FoldedItem], among indices: [Int], recent: [String]) -> [Int] {
        let recency = Self.order(of: recent)
        return indices.compactMap { index in
            match(items[index]).map { (rank: $0.rank, recency: recency[items[index].item.run] ?? Int.max, index: index) }
        }
        .sorted { ($0.rank, $0.recency, $0.index) < ($1.rank, $1.recency, $1.index) }
        .map(\.index)
    }

    /// Whether each item that matches this text also matches the given text, so that a search for it may look only among the
    /// matches of this one. A letters-in-order match needs three letters, so a last word of fewer may match fewer items.
    func narrows(to text: String) -> Bool {
        guard !words.isEmpty, text.hasPrefix(self.text) else { return false }
        let added = text.dropFirst(self.text.count)
        return (words.last?.count ?? 0) >= 3 || added.first?.isWhitespace == true
    }

    /// The items that match in each list, as one ranking, with the index of the list each came from.
    public func matching(in lists: [ItemList]) -> [(list: Int, item: SpotItem)] {
        lists.enumerated()
            .flatMap { index, list in
                ranked(list.folded, recent: list.recent).map { (list: index, match: $0) }
            }
            .sorted { first, second in
                let one = first.match, two = second.match
                return (one.rank, one.recency == Int.max ? 1 : 0, first.list, one.recency, one.offset)
                    < (two.rank, two.recency == Int.max ? 1 : 0, second.list, two.recency, two.offset)
            }
            .map { (list: $0.list, item: $0.match.item) }
    }

    private func ranked(_ items: [FoldedItem], recent: [String]) -> [(rank: Int, recency: Int, offset: Int, item: SpotItem)] {
        let recency = Self.order(of: recent)
        return items.enumerated().compactMap { offset, folded in
            match(folded).map { (rank: $0.rank, recency: recency[folded.item.run] ?? Int.max, offset: offset, item: folded.item) }
        }
    }

    /// The place of each picked run: the most picks first, then the latest pick.
    private static func order(of picks: [String]) -> [String: Int] {
        let counts = Dictionary(picks.map { ($0, 1) }, uniquingKeysWith: +)
        let latest = Dictionary(picks.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        let runs = latest.keys.sorted { (-counts[$0, default: 0], latest[$0, default: 0]) < (-counts[$1, default: 0], latest[$1, default: 0]) }
        return Dictionary(uniqueKeysWithValues: runs.enumerated().map { ($1, $0) })
    }

    private func match(_ item: FoldedItem) -> (rank: Int, marks: SearchMarks)? {
        guard !words.isEmpty else { return (0, SearchMarks(title: [], subtitle: [])) }
        if let glyph = item.glyph, glyph == FoldedItem.plain(text) { return (0, SearchMarks(title: [], subtitle: [])) }
        let title = item.title
        if title.letters == letters { return (0, SearchMarks(title: [0..<letters.count], subtitle: [])) }
        if title.letters.starts(with: letters) { return (1, SearchMarks(title: [0..<letters.count], subtitle: [])) }
        let subtitle = item.subtitle
        var rank = 0
        var marks: (title: [Range<Int>], subtitle: [Range<Int>]) = ([], [])
        for word in words {
            guard let found = Self.match(word, title: title, keywords: item.keywords, subtitle: subtitle) else { return nil }
            rank = max(rank, found.rank)
            marks.title += found.title
            marks.subtitle += found.subtitle
        }
        return (rank, SearchMarks(title: marks.title, subtitle: marks.subtitle))
    }

    private static func match(_ word: [UInt64], title: FoldedText, keywords: [FoldedText], subtitle: FoldedText?) -> (rank: Int, title: [Range<Int>], subtitle: [Range<Int>])? {
        let span = { (start: Int) in start..<start + word.count }
        let inTitle = title.occurrences(of: word)
        if let start = inTitle.first(where: title.starts.contains) { return (2, [span(start)], []) }
        if let found = title.inOrder(word, among: title.starts) { return (3, found.map { $0..<$0 + 1 }, []) }
        if let start = inTitle.first { return (4, [span(start)], []) }
        if keywords.contains(where: { $0.letters.starts(with: word) }) { return (5, [], []) }
        if let subtitle {
            let inSubtitle = subtitle.occurrences(of: word)
            if let start = inSubtitle.first(where: subtitle.starts.contains) { return (6, [], [span(start)]) }
            if let start = inSubtitle.first { return (7, [], [span(start)]) }
        }
        if word.count >= 3, let found = title.inOneWord(word) {
            return (8, found.map { $0..<$0 + 1 }, [])
        }
        return nil
    }
}
