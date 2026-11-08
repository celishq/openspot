import Foundation

/// The words of an empty search field.
public enum SearchPrompt {
    public static let verb = "Search"
    public static let grid = "spots"

    /// A title as it reads inside a sentence. A word with a capital after its first letter keeps its case.
    public static func word(for title: String) -> String {
        title.split(separator: " ", omittingEmptySubsequences: false).map { word in
            word.dropFirst().contains(where: \.isUppercase) ? String(word) : word.lowercased()
        }.joined(separator: " ")
    }
}
