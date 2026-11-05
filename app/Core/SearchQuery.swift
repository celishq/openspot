import Foundation

/// Text that finds and ranks items: the title start, a word start, the initials, any part of the title,
/// then any part of the subtitle. Within a rank, recent picks come first, then the given order.
public struct SearchQuery: Equatable, Sendable {
    public let text: String
    private let folded: String

    public init(text: String) {
        self.text = text.trimmingCharacters(in: .whitespaces)
        folded = Self.fold(self.text)
    }

    public func matching(_ items: [SpotItem], recent: [String] = []) -> [SpotItem] {
        let recency = Dictionary(recent.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        let ranked = items.enumerated().compactMap { offset, item in
            rank(of: item).map { (rank: $0, recency: recency[item.run] ?? Int.max, offset: offset, item: item) }
        }
        return ranked
            .sorted { ($0.rank, $0.recency, $0.offset) < ($1.rank, $1.recency, $1.offset) }
            .map(\.item)
    }

    private func rank(of item: SpotItem) -> Int? {
        guard !folded.isEmpty else { return 0 }
        let title = Self.fold(item.title)
        if title.hasPrefix(folded) { return 0 }
        let starts = Self.wordStarts(in: item.title)
        if starts.contains(where: { Self.fold(String(item.title[$0...])).hasPrefix(folded) }) { return 1 }
        if Self.fold(String(starts.map { item.title[$0] })).hasPrefix(folded) { return 2 }
        if title.contains(folded) { return 3 }
        if let subtitle = item.subtitle, Self.fold(subtitle).contains(folded) { return 4 }
        return nil
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
