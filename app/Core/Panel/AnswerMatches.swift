import Foundation

/// Which `answers` patterns match the text of the main search (A2). It matches each pattern once for each text.
struct AnswerMatches {
    private var text = ""
    private var found: [String: Bool] = [:]
    /// The number of times that it matched a pattern with a text.
    private(set) var count = 0

    /// Whether the pattern finds a match in the text.
    mutating func matches(_ pattern: AnswerPattern, _ text: String) -> Bool {
        if text != self.text {
            self.text = text
            found = [:]
        }
        if let known = found[pattern.text] { return known }
        count += 1
        let match = pattern.matches(text)
        found[pattern.text] = match
        return match
    }
}
