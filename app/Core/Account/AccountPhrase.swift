import Foundation

public struct AccountPhrase: Sendable {
    public struct TypedWord: Equatable, Sendable {
        public let text: String
        public let isKnown: Bool
    }

    public static let wordCount = 12
    private static let nsecLength = 63

    public let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var typed: [TypedWord] {
        guard !isNsec else { return [] }
        let words = text.split(whereSeparator: \.isWhitespace).map { $0.lowercased() }
        let isTyping = text.last.map { !$0.isWhitespace } ?? false
        return words.enumerated().map { index, word in
            let isLast = index == words.count - 1 && isTyping
            return TypedWord(text: word, isKnown: isLast ? !Self.suggestions(for: word).isEmpty : AccountWords.all.contains(word))
        }
    }

    public var counter: String {
        "\(typed.count) of \(Self.wordCount)"
    }

    public var completion: String? {
        guard !isNsec, let last = text.last, !last.isWhitespace, let word = typed.last?.text else { return nil }
        return Self.suggestions(for: word).first.flatMap { $0 == word ? nil : $0 }
    }

    public var account: String? {
        canSignIn ? (try? key())?.npub : nil
    }

    public var problem: String? {
        if isNsec {
            guard trimmed.count >= Self.nsecLength else { return nil }
            return (try? key()) == nil ? "This is not an nsec." : nil
        }
        let words = typed
        guard words.count >= Self.wordCount else { return nil }
        guard words.count == Self.wordCount else { return "An account has \(Self.wordCount) words, and this has \(words.count)." }
        if let unknown = words.first(where: { !AccountWords.all.contains($0.text) }) { return "\(unknown.text) isn't one of the account words." }
        return (try? key()) == nil ? "These words don't match an account. Check each word and their order." : nil
    }

    public var canSignIn: Bool {
        (isNsec ? trimmed.count >= Self.nsecLength : typed.count == Self.wordCount) && problem == nil
    }

    public func key() throws -> AccountKey {
        isNsec ? try AccountKey(nsec: trimmed) : try AccountKey(words: typed.map(\.text))
    }

    public static func suggestions(for letters: String) -> [String] {
        let letters = letters.lowercased()
        guard !letters.isEmpty else { return [] }
        return AccountWords.all.filter { $0.hasPrefix(letters) }
    }

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isNsec: Bool {
        trimmed.lowercased().hasPrefix("nsec1")
    }
}
