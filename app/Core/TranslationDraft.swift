import Foundation

/// The two languages and the two texts of the translate screen. No source language means automatic detection.
public struct TranslationDraft: Equatable, Sendable {
    private static let fallback = "en"

    public private(set) var source: String?
    public private(set) var target: String
    public var input = ""
    public private(set) var output = ""
    public private(set) var detected: String?
    private let preferred: [String]

    public init(preferred: [String], source: String? = nil, target: String? = nil) {
        let codes = TranslationTargets(preferred: preferred, source: "").codes
        self.preferred = codes + [Self.fallback]
        self.source = source
        self.target = target ?? codes.dropFirst().first ?? codes.first ?? Self.fallback
    }

    /// The language the input is in, as chosen or as detected.
    public var from: String? {
        source ?? detected
    }

    public var hasInput: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var canSwap: Bool {
        from != nil
    }

    /// Whether the input and the output are in different languages.
    public var needsTranslation: Bool {
        from.map { !Self.isSame($0, target) } ?? false
    }

    public mutating func take(output: String) {
        self.output = output
    }

    /// Keeps the language found in the input. When the input is already in the target, the target moves on.
    public mutating func take(detected code: String?) {
        detected = code
        guard source == nil, let code, Self.isSame(code, target) else { return }
        target = preferred.first { !Self.isSame($0, code) } ?? target
    }

    /// Chooses the input language. Choosing the target makes the old input language the target.
    public mutating func choose(source code: String?) {
        if let code, Self.isSame(code, target), let old = from { target = old }
        source = code
    }

    /// Chooses the output language. Choosing the input language makes the old target the input language.
    public mutating func choose(target code: String) {
        if let from, Self.isSame(from, code) {
            source = target
        }
        target = code
    }

    /// Trades the two languages and the two texts. Text with no translation yet stays where it is.
    public mutating func swap() {
        guard let from else { return }
        source = target
        target = from
        detected = nil
        if !output.isEmpty {
            (input, output) = (output, input)
        }
    }

    private static func isSame(_ one: String, _ other: String) -> Bool {
        one.prefix { $0 != "-" } == other.prefix { $0 != "-" }
    }
}
