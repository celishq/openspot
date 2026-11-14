import Foundation

public struct SearchQuery: Equatable, Sendable {
    public let text: String
    public let forms: [String]
    private let typed: Form
    private let converted: [Form]
    private let plain: String

    public var input: String {
        TextBlock(fields: [.init(key: "search", value: text)] + forms.map { .init(key: "form", value: $0) }).text
    }

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

    private static func retyped(_ text: String, layouts: [KeyLayout]) -> [String] {
        layouts.flatMap { from in layouts.filter { $0 != from }.compactMap { from.text(text, in: $0) } }
    }

    private static func latin(_ text: String) -> [String] {
        guard !text.allSatisfy(\.isASCII) else { return [] }
        return [text.applyingTransform(.toLatin, reverse: false)?.applyingTransform(.stripDiacritics, reverse: false)].compactMap { $0 }
    }

    public func matching(_ items: [SpotItem], recent: [String] = []) -> [SpotItem] {
        ranking(SearchIndex(items), items: items, among: Array(items.indices), weights: PickWeights(recent)).map { items[$0] }
    }

    func ranking(_ index: SearchIndex, items: [SpotItem], among indices: [Int], weights: PickWeights) -> [Int] {
        index.withItems { folded in
            indices.compactMap { index in
                match(folded[index]).map { (rank: $0, weight: weights.weight(of: items[index].run), index: index) }
            }
        }
        .sorted { ($0.rank, -$0.weight, $0.index) < ($1.rank, -$1.weight, $1.index) }
        .map(\.index)
    }

    func narrows(to next: SearchQuery) -> Bool {
        guard let last = typed.words.last, next.text.hasPrefix(text) else { return false }
        let added = next.text.dropFirst(text.count)
        let staysShort = last.count + added.prefix { !$0.isWhitespace }.count < 3
            && next.text.allSatisfy { $0.isLetter || $0.isNumber || $0.isWhitespace }
        guard last.count >= 3 || added.first?.isWhitespace == true || staysShort else { return false }
        return next.forms.allSatisfy { form in forms.contains { form.hasPrefix($0) } }
    }

    public func matching(in lists: [ItemList], unpickedLimit: Int = .max, limit: Int = .max) -> [(list: Int, item: SpotItem)] {
        var search = MainSearch()
        return search.matching(self, in: lists, unpickedLimit: unpickedLimit, limit: limit)
    }

    typealias Ranked = (rank: Int, weight: Double, offset: Int)

    func ranked(_ index: SearchIndex, items: [SpotItem], among offsets: [Int], weights: PickWeights) -> [Ranked] {
        index.withItems { folded in
            offsets.compactMap { offset in
                match(folded[offset]).map { (rank: $0, weight: weights.weight(of: items[offset].run), offset: offset) }
            }
        }
    }

    static func best(_ matches: [Ranked], count: Int) -> [Ranked] {
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
