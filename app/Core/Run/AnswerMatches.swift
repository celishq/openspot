import Foundation

struct AnswerMatches {
    private var text = ""
    private var found: [String: Bool] = [:]
    private(set) var count = 0

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
