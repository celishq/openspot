import Foundation

/// Text that finds and ranks items. The whole title ranks first, then the title start. Otherwise each word must match,
/// and the worst word sets the rank: a word start, the initials in order, any part of the title, a word start of the
/// subtitle, any part of the subtitle, then three or more letters in order in one word of the title. Within a rank, the
/// item with the most weight of picks comes first, and each pick weighs less as later picks come. Then an earlier list
/// wins, then the given order.
public struct SearchQuery: Equatable, Sendable {
    public let text: String
    private let letters: [String]
    private let words: [[String]]

    public init(text: String) {
        self.text = text.trimmingCharacters(in: .whitespaces)
        letters = self.text.map { Self.fold(String($0)) }
        words = self.text.split(whereSeparator: \.isWhitespace).map { $0.map { Self.fold(String($0)) } }
    }

    /// The letters of the item that this text matches. An item that does not match has none.
    public func marks(in item: SpotItem) -> SearchMarks {
        match(item)?.marks ?? SearchMarks(title: [], subtitle: [])
    }

    public func matching(_ items: [SpotItem], recent: [String] = []) -> [SpotItem] {
        ranked(items, recent: recent)
            .sorted { ($0.rank, -$0.weight, $0.offset) < ($1.rank, -$1.weight, $1.offset) }
            .map(\.item)
    }

    /// The items that match in each list, as one ranking, with the index of the list each came from. Each list after the
    /// first that has no pick gives at most `unpickedLimit` items.
    public func matching(in lists: [ItemList], unpickedLimit: Int = .max) -> [(list: Int, item: SpotItem)] {
        lists.enumerated()
            .flatMap { index, list in
                let found = ranked(list.all, recent: list.recent).sorted { ($0.rank, $0.offset) < ($1.rank, $1.offset) }
                return found.prefix(index > 0 && list.recent.isEmpty ? unpickedLimit : found.count).map { (list: index, match: $0) }
            }
            .sorted { first, second in
                let one = first.match, two = second.match
                return (one.rank, -one.weight, first.list, one.offset) < (two.rank, -two.weight, second.list, two.offset)
            }
            .map { (list: $0.list, item: $0.match.item) }
    }

    private func ranked(_ items: [SpotItem], recent: [String]) -> [(rank: Int, weight: Double, offset: Int, item: SpotItem)] {
        let weights = Self.weights(of: recent)
        return items.enumerated().compactMap { offset, item in
            rank(of: item).map { (rank: $0, weight: weights[item.run] ?? 0, offset: offset, item: item) }
        }
    }

    /// The weight of each picked run, from the latest pick first: each pick weighs 0.9 of the one after it.
    private static func weights(of picks: [String]) -> [String: Double] {
        var weights: [String: Double] = [:]
        var weight = 1.0
        for run in picks {
            weights[run, default: 0] += weight
            weight *= 0.9
        }
        return weights
    }

    private func rank(of item: SpotItem) -> Int? {
        match(item)?.rank
    }

    private func match(_ item: SpotItem) -> (rank: Int, marks: SearchMarks)? {
        guard !words.isEmpty else { return (0, SearchMarks(title: [], subtitle: [])) }
        let title = Folded(item.title)
        if title.letters == letters { return (0, SearchMarks(title: [0..<letters.count], subtitle: [])) }
        if title.letters.starts(with: letters) { return (1, SearchMarks(title: [0..<letters.count], subtitle: [])) }
        let subtitle = item.subtitle.map(Folded.init)
        var rank = 0
        var marks: (title: [Range<Int>], subtitle: [Range<Int>]) = ([], [])
        for word in words {
            guard let found = Self.match(word, title: title, subtitle: subtitle) else { return nil }
            rank = max(rank, found.rank)
            marks.title += found.title
            marks.subtitle += found.subtitle
        }
        return (rank, SearchMarks(title: marks.title, subtitle: marks.subtitle))
    }

    private static func match(_ word: [String], title: Folded, subtitle: Folded?) -> (rank: Int, title: [Range<Int>], subtitle: [Range<Int>])? {
        let span = { (start: Int) in start..<start + word.count }
        let inTitle = title.occurrences(of: word)
        if let start = inTitle.first(where: title.starts.contains) { return (2, [span(start)], []) }
        if let found = title.inOrder(word, among: title.starts) { return (3, found.map { $0..<$0 + 1 }, []) }
        if let start = inTitle.first { return (4, [span(start)], []) }
        if let subtitle {
            let inSubtitle = subtitle.occurrences(of: word)
            if let start = inSubtitle.first(where: subtitle.starts.contains) { return (5, [], [span(start)]) }
            if let start = inSubtitle.first { return (6, [], [span(start)]) }
        }
        if word.count >= 3, let found = title.inOneWord(word) {
            return (7, found.map { $0..<$0 + 1 }, [])
        }
        return nil
    }

    /// Text as one folded string per character, with the offsets where its words begin.
    private struct Folded {
        let letters: [String]
        let starts: [Int]

        /// A word begins after a character that is not a letter or a digit, or at a capital after a small letter.
        init(_ text: String) {
            let characters = Array(text)
            letters = characters.map { SearchQuery.fold(String($0)) }
            starts = characters.indices.filter { index in
                let character = characters[index]
                guard character.isLetter || character.isNumber else { return false }
                guard index > 0 else { return true }
                let previous = characters[index - 1]
                return !(previous.isLetter || previous.isNumber) || (character.isUppercase && previous.isLowercase)
            }
        }

        func occurrences(of word: [String]) -> [Int] {
            guard !word.isEmpty, word.count <= letters.count else { return [] }
            return (0...(letters.count - word.count)).filter { letters[$0..<$0 + word.count].elementsEqual(word) }
        }

        /// The offsets of the first word whose letters spell the word in order.
        func inOneWord(_ word: [String]) -> [Int]? {
            zip(starts, starts.dropFirst() + [letters.count]).lazy.compactMap { inOrder(word, among: Array($0..<$1)) }.first
        }

        /// The first offsets among the given ones whose letters spell the word in order.
        func inOrder(_ word: [String], among offsets: [Int]) -> [Int]? {
            var found: [Int] = []
            var rest = offsets[...]
            for letter in word {
                guard let index = rest.firstIndex(where: { letters[$0] == letter }) else { return nil }
                found.append(rest[index])
                rest = rest[(index + 1)...]
            }
            return found
        }
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
