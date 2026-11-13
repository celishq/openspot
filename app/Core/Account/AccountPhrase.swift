import Foundation

/// What a person typed or pasted to sign in, the 12 words or an `nsec`, and how far it is from an account: each word with
/// whether it is one of the list, a completion of the word being typed, a problem, and the account it opens.
public struct AccountPhrase: Sendable {
    /// One word of the phrase, and whether it is a word of the list, or starts one while it is being typed.
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

    /// Each word of the phrase. The last one is still being typed until a space follows it.
    public var typed: [TypedWord] {
        guard !isNsec else { return [] }
        let words = text.split(whereSeparator: \.isWhitespace).map { $0.lowercased() }
        let isTyping = text.last.map { !$0.isWhitespace } ?? false
        return words.enumerated().map { index, word in
            let isLast = index == words.count - 1 && isTyping
            return TypedWord(text: word, isKnown: isLast ? !Self.suggestions(for: word).isEmpty : AccountWords.all.contains(word))
        }
    }

    /// How many words the phrase holds, such as `8 of 12`.
    public var counter: String {
        "\(typed.count) of \(Self.wordCount)"
    }

    /// The word of the list that the word being typed starts.
    public var completion: String? {
        guard !isNsec, let last = text.last, !last.isWhitespace, let word = typed.last?.text else { return nil }
        return Self.suggestions(for: word).first.flatMap { $0 == word ? nil : $0 }
    }

    /// The `npub` of the account that the phrase opens, once it is one.
    public var account: String? {
        canSignIn ? (try? key())?.npub : nil
    }

    /// Why the phrase is no account, once it is long enough to be one, or nil.
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

    /// What the phrase is so far, as one block: its counter, the places of its unknown words, a completion, a problem, or
    /// the account it opens.
    public var facts: String {
        var fields = [TextBlock.Field(key: "counter", value: counter)]
        let unknown = typed.indices.filter { !typed[$0].isKnown }.map { String($0 + 1) }
        if !unknown.isEmpty { fields.append(.init(key: "unknown", value: unknown.joined(separator: " "))) }
        if let completion { fields.append(.init(key: "completion", value: completion)) }
        if let problem { fields.append(.init(key: "problem", value: problem)) }
        if let account { fields.append(.init(key: "account", value: account)) }
        return TextBlock(fields: fields).text
    }

    /// The key of the phrase.
    public func key() throws -> AccountKey {
        isNsec ? try AccountKey(nsec: trimmed) : try AccountKey(words: typed.map(\.text))
    }

    /// The words of the list that start with these letters.
    public static func suggestions(for letters: String) -> [String] {
        let letters = letters.lowercased()
        guard !letters.isEmpty else { return [] }
        return AccountWords.all.filter { $0.hasPrefix(letters) }
    }

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whether the phrase is an `nsec`, by its start.
    private var isNsec: Bool {
        trimmed.lowercased().hasPrefix("nsec1")
    }
}
