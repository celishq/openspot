import Foundation

public enum SearchPrompt {
    public static let verb = "Search"
    public static let grid = "spots"
    static let slashHint = "Type / and a spot's name to run it with text"

    public static func word(for title: String) -> String {
        title.split(separator: " ", omittingEmptySubsequences: false).map { word in
            word.dropFirst().contains(where: \.isUppercase) ? String(word) : word.lowercased()
        }.joined(separator: " ")
    }
}
