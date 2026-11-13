import Foundation

/// The words of a hint under the panel, as groups of a key and the words that say what it does.
public struct HintWords: Hashable, Sendable {
    public struct Group: Hashable, Sendable {
        public let key: String?
        public let words: String
    }

    private static let keySymbols = CharacterSet(charactersIn: "⌘⌥⌃⇧⏎↩⌫⎋↑↓←→")
    private static let keyNames: Set<String> = ["Esc", "Tab", "Space", "Return", "Delete"]

    public let groups: [Group]

    public init(_ text: String) {
        groups = text.components(separatedBy: "  ").compactMap { group in
            let words = group.split(separator: " ").map(String.init)
            guard let first = words.first else { return nil }
            let rest = words.dropFirst().joined(separator: " ")
            guard Self.isKey(first, hasWords: !rest.isEmpty) else { return Group(key: nil, words: words.joined(separator: " ")) }
            return Group(key: first, words: rest)
        }
    }

    private static func isKey(_ word: String, hasWords: Bool) -> Bool {
        if word.unicodeScalars.contains(where: keySymbols.contains) || keyNames.contains(word) { return true }
        return hasWords && word.count == 1 && word.first?.isUppercase == true
    }
}
