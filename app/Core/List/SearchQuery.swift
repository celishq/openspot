import Foundation

/// Text that finds and ranks items. The glyph and the whole title rank first, then the title start. Otherwise each word
/// must match, and the worst word sets the rank: a word start, the initials, any part of the title, a keyword start, a word
/// start of the subtitle, any part of the subtitle, then three or more letters in order in one word of the title. Within a
/// rank, the item with the most weight of picks comes first, and each pick weighs less as later picks come. Then an earlier
/// list wins, then the given order. A form of the text, such as its Latin spelling, matches too, just below the typed text
/// of the same rank, and never by letters in order.
public struct SearchQuery: Equatable, Sendable {
    public let text: String
    /// The other texts that the person may have meant: the text typed on the same keys of each other layout, then the text
    /// spelled in Latin letters.
    public let forms: [String]
    private let typed: Form
    private let converted: [Form]
    /// The text as a glyph matches it whole: with no mark that asks for a picture or a text form.
    private let plain: String

    public init(text: String, layouts: [KeyLayout] = KeyLayout.enabled) {
        self.text = text.trimmingCharacters(in: .whitespaces)
        plain = FoldedItem.plain(self.text)
        let typed = Form(self.text)
        self.typed = typed
        let candidates = Self.retyped(self.text, layouts: layouts) + Self.latin(self.text)
        var seen = [typed.words]
        forms = candidates.filter { candidate in
            let words = Form(candidate).words
            guard !seen.contains(words) else { return false }
            seen.append(words)
            return true
        }
        converted = forms.map(Form.init)
    }

    /// The text typed on the same keys of each other layout.
    private static func retyped(_ text: String, layouts: [KeyLayout]) -> [String] {
        layouts.flatMap { from in layouts.filter { $0 != from }.compactMap { from.text(text, in: $0) } }
    }

    /// The text spelled in Latin letters with no accents, when it holds other letters.
    private static func latin(_ text: String) -> [String] {
        guard !text.allSatisfy(\.isASCII) else { return [] }
        return [text.applyingTransform(.toLatin, reverse: false)?.applyingTransform(.stripDiacritics, reverse: false)].compactMap { $0 }
    }

    public func matching(_ items: [SpotItem], recent: [String] = []) -> [SpotItem] {
        ranking(SearchIndex(items), items: items, among: Array(items.indices), recent: recent).map { items[$0] }
    }

    /// The indices of the items among the given ones that match, best first. The index holds the texts of the items.
    func ranking(_ index: SearchIndex, items: [SpotItem], among indices: [Int], recent: [String]) -> [Int] {
        let weights = Self.weights(of: recent)
        return index.withItems { folded in
            indices.compactMap { index in
                match(folded[index]).map { (rank: $0, weight: weights[items[index].run] ?? 0, index: index) }
            }
        }
        .sorted { ($0.rank, -$0.weight, $0.index) < ($1.rank, -$1.weight, $1.index) }
        .map(\.index)
    }

    /// Whether each item that matches this text also matches the given text, so that a search for it may look only among the
    /// matches of this one. A letters-in-order match needs three letters, so a last word that reaches three letters only now
    /// may match more items; a short text of other characters may be a glyph; and each form of the given text must grow a form
    /// of this one.
    func narrows(to next: SearchQuery) -> Bool {
        guard let last = typed.words.last, next.text.hasPrefix(text) else { return false }
        let added = next.text.dropFirst(text.count)
        let staysShort = last.count + added.prefix { !$0.isWhitespace }.count < 3
            && next.text.allSatisfy { $0.isLetter || $0.isNumber || $0.isWhitespace }
        guard last.count >= 3 || added.first?.isWhitespace == true || staysShort else { return false }
        return next.forms.allSatisfy { form in forms.contains { form.hasPrefix($0) } }
    }

    /// The best `limit` items that match in all lists, as one ranking, with the index of the list each came from. Each list
    /// after the first that has no pick gives at most `unpickedLimit` items. Each list keeps only its own best, and only
    /// the items kept are copied out.
    public func matching(in lists: [ItemList], unpickedLimit: Int = .max, limit: Int = .max) -> [(list: Int, item: SpotItem)] {
        lists.enumerated()
            .flatMap { index, list in
                let texts = list.search == .local ? list.searchIndex : SearchIndex(list.all)
                let count = min(limit, index > 0 && list.recent.isEmpty ? unpickedLimit : .max)
                return Self.best(ranked(texts, items: list.all, recent: list.recent), count: count).map { (list: index, match: $0) }
            }
            .sorted { first, second in
                let one = first.match, two = second.match
                return (one.rank, -one.weight, first.list, one.offset) < (two.rank, -two.weight, second.list, two.offset)
            }
            .prefix(limit)
            .map { (list: $0.list, item: lists[$0.list].all[$0.match.offset]) }
    }

    /// One item that matches: its rank, the weight of its picks and its place in its list.
    private typealias Ranked = (rank: Int, weight: Double, offset: Int)

    private func ranked(_ index: SearchIndex, items: [SpotItem], recent: [String]) -> [Ranked] {
        let weights = Self.weights(of: recent)
        return index.withItems { folded in
            items.indices.compactMap { offset in
                match(folded[offset]).map { (rank: $0, weight: weights[items[offset].run] ?? 0, offset: offset) }
            }
        }
    }

    /// The best `count` matches of one list: by rank, then by the weight of picks, then by place.
    private static func best(_ matches: [Ranked], count: Int) -> [Ranked] {
        guard count < matches.count else { return matches }
        let precedes = { (one: Ranked, two: Ranked) in (one.rank, -one.weight, one.offset) < (two.rank, -two.weight, two.offset) }
        var kept: [Ranked] = []
        kept.reserveCapacity(count + 1)
        for match in matches where kept.count < count || precedes(match, kept[kept.count - 1]) {
            kept.insert(match, at: kept.firstIndex { precedes(match, $0) } ?? kept.count)
            if kept.count > count { kept.removeLast() }
        }
        return kept
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

    private func match(_ item: FoldedItem) -> Int? {
        guard !typed.words.isEmpty else { return 0 }
        if let glyph = item.glyph, glyph == plain { return 0 }
        var best = Self.match(typed, in: item, loose: true).map { $0 * 2 }
        for form in converted {
            if let rank = Self.match(form, in: item, loose: false).map({ $0 * 2 + 1 }), rank < best ?? .max { best = rank }
        }
        return best
    }

    private static func match(_ form: Form, in item: FoldedItem, loose: Bool) -> Int? {
        guard form.letterBits & ~item.letterBits == 0 else { return nil }
        let title = item.title
        if title.letters.elementsEqual(form.letters) { return 0 }
        if title.letters.starts(with: form.letters) { return 1 }
        var rank = 0
        for word in form.words {
            guard let found = match(word, title: title, keywords: item.keywords, subtitle: item.subtitle, loose: loose) else { return nil }
            rank = max(rank, found)
        }
        return rank
    }

    private static func match(_ word: [UInt32], title: FoldedText, keywords: SearchIndex.Texts, subtitle: FoldedText?, loose: Bool) -> Int? {
        let inTitle = title.place(of: word)
        if inTitle == .wordStart { return 2 }
        if title.spellsAtWordStarts(word) { return 3 }
        if inTitle == .inside { return 4 }
        if keywords.contains(where: { $0.letters.starts(with: word) }) { return 5 }
        switch subtitle?.place(of: word) {
        case .wordStart: return 6
        case .inside: return 7
        case nil: break
        }
        if loose, word.count >= 3, title.spellsInOneWord(word) { return 8 }
        return nil
    }

    /// A text as folded letters, whole and split into words.
    private struct Form: Equatable, Sendable {
        let letters: [UInt32]
        let words: [[UInt32]]
        let letterBits: UInt64

        init(_ text: String) {
            letters = text.map(FoldedText.code)
            words = text.split(whereSeparator: \.isWhitespace).map { $0.map(FoldedText.code) }
            letterBits = words.joined().reduce(0) { $0 | FoldedText.bit(of: $1) }
        }
    }
}
