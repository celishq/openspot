import Foundation

/// Text that finds and ranks items. The glyph and the whole title rank first, then the title start. Otherwise each word
/// must match, and the worst word sets the rank: a word start, the initials, any part of the title, a keyword start, a word
/// start of the subtitle, any part of the subtitle, then three or more letters in order in one word of the title. Within a
/// rank, the item with the most weight of picks comes first, and each pick weighs less as later picks come. Then an earlier
/// list wins, then the given order. A form of the text, such as its Latin spelling, matches too, just below the typed text
/// of the same rank, and never by letters in order.
public struct SearchQuery: Equatable, Sendable {
    public let text: String
    /// The other texts that the person may have meant, such as the text spelled in Latin letters.
    public let forms: [String]
    private let typed: Form
    private let converted: [Form]

    public init(text: String) {
        self.text = text.trimmingCharacters(in: .whitespaces)
        let typed = Form(self.text)
        self.typed = typed
        forms = Self.latin(self.text).filter { Form($0).words != typed.words }
        converted = forms.map(Form.init)
    }

    /// The text spelled in Latin letters with no accents, when it holds other letters.
    private static func latin(_ text: String) -> [String] {
        guard !text.allSatisfy(\.isASCII) else { return [] }
        return [text.applyingTransform(.toLatin, reverse: false)?.applyingTransform(.stripDiacritics, reverse: false)].compactMap { $0 }
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
        let weights = Self.weights(of: recent)
        return indices.compactMap { index in
            match(items[index]).map { (rank: $0.rank, weight: weights[items[index].item.run] ?? 0, index: index) }
        }
        .sorted { ($0.rank, -$0.weight, $0.index) < ($1.rank, -$1.weight, $1.index) }
        .map(\.index)
    }

    /// Whether each item that matches this text also matches the given text, so that a search for it may look only among the
    /// matches of this one. A letters-in-order match needs three letters, so a last word of fewer may match fewer items, and
    /// each form of the given text must grow a form of this one.
    func narrows(to next: SearchQuery) -> Bool {
        guard !typed.words.isEmpty, next.text.hasPrefix(text) else { return false }
        let added = next.text.dropFirst(text.count)
        guard (typed.words.last?.count ?? 0) >= 3 || added.first?.isWhitespace == true else { return false }
        return next.forms.allSatisfy { form in forms.contains { form.hasPrefix($0) } }
    }

    /// The items that match in each list, as one ranking, with the index of the list each came from. Each list after the
    /// first that has no pick gives at most `unpickedLimit` items.
    public func matching(in lists: [ItemList], unpickedLimit: Int = .max) -> [(list: Int, item: SpotItem)] {
        lists.enumerated()
            .flatMap { index, list in
                let found = ranked(list.folded, recent: list.recent).sorted { ($0.rank, $0.offset) < ($1.rank, $1.offset) }
                return found.prefix(index > 0 && list.recent.isEmpty ? unpickedLimit : found.count).map { (list: index, match: $0) }
            }
            .sorted { first, second in
                let one = first.match, two = second.match
                return (one.rank, -one.weight, first.list, one.offset) < (two.rank, -two.weight, second.list, two.offset)
            }
            .map { (list: $0.list, item: $0.match.item) }
    }

    private func ranked(_ items: [FoldedItem], recent: [String]) -> [(rank: Int, weight: Double, offset: Int, item: SpotItem)] {
        let weights = Self.weights(of: recent)
        return items.enumerated().compactMap { offset, folded in
            match(folded).map { (rank: $0.rank, weight: weights[folded.item.run] ?? 0, offset: offset, item: folded.item) }
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

    private func match(_ item: FoldedItem) -> (rank: Int, marks: SearchMarks)? {
        guard !typed.words.isEmpty else { return (0, SearchMarks(title: [], subtitle: [])) }
        if let glyph = item.glyph, glyph == FoldedItem.plain(text) { return (0, SearchMarks(title: [], subtitle: [])) }
        let typedMatch = Self.match(typed, in: item, loose: true).map { (rank: $0.rank * 2, marks: $0.marks) }
        let convertedMatches = converted.compactMap { Self.match($0, in: item, loose: false) }.map { (rank: $0.rank * 2 + 1, marks: $0.marks) }
        return ([typedMatch].compactMap { $0 } + convertedMatches).min { $0.rank < $1.rank }
    }

    private static func match(_ form: Form, in item: FoldedItem, loose: Bool) -> (rank: Int, marks: SearchMarks)? {
        let title = item.title
        if title.letters == form.letters { return (0, SearchMarks(title: [0..<form.letters.count], subtitle: [])) }
        if title.letters.starts(with: form.letters) { return (1, SearchMarks(title: [0..<form.letters.count], subtitle: [])) }
        let subtitle = item.subtitle
        var rank = 0
        var marks: (title: [Range<Int>], subtitle: [Range<Int>]) = ([], [])
        for word in form.words {
            guard let found = match(word, title: title, keywords: item.keywords, subtitle: subtitle, loose: loose) else { return nil }
            rank = max(rank, found.rank)
            marks.title += found.title
            marks.subtitle += found.subtitle
        }
        return (rank, SearchMarks(title: marks.title, subtitle: marks.subtitle))
    }

    private static func match(_ word: [UInt64], title: FoldedText, keywords: [FoldedText], subtitle: FoldedText?, loose: Bool) -> (rank: Int, title: [Range<Int>], subtitle: [Range<Int>])? {
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
        if loose, word.count >= 3, let found = title.inOneWord(word) {
            return (8, found.map { $0..<$0 + 1 }, [])
        }
        return nil
    }

    /// A text as folded letters, whole and split into words.
    private struct Form: Equatable, Sendable {
        let letters: [UInt64]
        let words: [[UInt64]]

        init(_ text: String) {
            letters = text.map(FoldedText.code)
            words = text.split(whereSeparator: \.isWhitespace).map { $0.map(FoldedText.code) }
        }
    }
}
