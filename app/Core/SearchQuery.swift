import Foundation

/// Text that finds and ranks items: the title start, a word start, the initials in order, any part of the title,
/// then any part of the subtitle. Within a rank, recent picks come first, then the given order.
/// Across lists, a recent pick comes before any other item of its rank, and an earlier list wins what is left.
public struct SearchQuery: Equatable, Sendable {
    public let text: String
    private let folded: String

    public init(text: String) {
        self.text = text.trimmingCharacters(in: .whitespaces)
        folded = Self.fold(self.text)
    }

    public func matching(_ items: [SpotItem], recent: [String] = []) -> [SpotItem] {
        ranked(items, recent: recent)
            .sorted { ($0.rank, $0.recency, $0.offset) < ($1.rank, $1.recency, $1.offset) }
            .map(\.item)
    }

    /// The items that match in each list, as one ranking, with the index of the list each came from.
    public func matching(in lists: [ItemList]) -> [(list: Int, item: SpotItem)] {
        lists.enumerated()
            .flatMap { index, list in
                ranked(list.all, recent: list.recent).map { (list: index, match: $0) }
            }
            .sorted { first, second in
                let one = first.match, two = second.match
                return (one.rank, one.recency == Int.max ? 1 : 0, first.list, one.recency, one.offset)
                    < (two.rank, two.recency == Int.max ? 1 : 0, second.list, two.recency, two.offset)
            }
            .map { (list: $0.list, item: $0.match.item) }
    }

    private func ranked(_ items: [SpotItem], recent: [String]) -> [(rank: Int, recency: Int, offset: Int, item: SpotItem)] {
        let recency = Dictionary(recent.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return items.enumerated().compactMap { offset, item in
            rank(of: item).map { (rank: $0, recency: recency[item.run] ?? Int.max, offset: offset, item: item) }
        }
    }

    private func rank(of item: SpotItem) -> Int? {
        guard !folded.isEmpty else { return 0 }
        let title = Self.fold(item.title)
        if title.hasPrefix(folded) { return 0 }
        let starts = Self.wordStarts(in: item.title)
        if starts.contains(where: { Self.fold(String(item.title[$0...])).hasPrefix(folded) }) { return 1 }
        if Self.isInOrder(folded, in: Self.fold(String(starts.map { item.title[$0] }))) { return 2 }
        if title.contains(folded) { return 3 }
        if let subtitle = item.subtitle, Self.fold(subtitle).contains(folded) { return 4 }
        return nil
    }

    private static func isInOrder(_ letters: String, in text: String) -> Bool {
        var rest = text[...]
        for letter in letters {
            guard let found = rest.firstIndex(of: letter) else { return false }
            rest = rest[rest.index(after: found)...]
        }
        return true
    }

    /// Where each word begins: after a character that is not a letter or a digit, or at a capital after a small letter.
    private static func wordStarts(in title: String) -> [String.Index] {
        var starts: [String.Index] = []
        var previous: Character?
        for index in title.indices {
            let character = title[index]
            if character.isLetter || character.isNumber {
                let afterGap = previous.map { !$0.isLetter && !$0.isNumber } ?? true
                let isCapitalAfterSmall = character.isUppercase && previous?.isLowercase == true
                if afterGap || isCapitalAfterSmall { starts.append(index) }
            }
            previous = character
        }
        return starts
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
