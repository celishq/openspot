import Foundation

public struct ActionLine: Equatable, Sendable {
    public let words: [String]

    public init?(text: String) {
        var words: [String] = []
        var word = ""
        var holds = false
        var quote: Character?
        var escapes = false
        for character in text {
            if escapes {
                word.append(character)
                escapes = false
            } else if quote == "'" {
                if character == "'" { quote = nil } else { word.append(character) }
            } else if character == "\\" {
                escapes = true
                holds = true
            } else if quote == "\"" {
                if character == "\"" { quote = nil } else { word.append(character) }
            } else if character == "'" || character == "\"" {
                quote = character
                holds = true
            } else if character.isWhitespace {
                if holds { words.append(word) }
                word = ""
                holds = false
            } else {
                word.append(character)
                holds = true
            }
        }
        guard quote == nil, !escapes else { return nil }
        if holds { words.append(word) }
        guard !words.isEmpty else { return nil }
        self.words = words
    }

    public static func text(of words: [String]) -> String {
        words.map { word in
            let isPlain = !word.isEmpty && !word.contains { $0.isWhitespace || "'\"\\".contains($0) }
            return isPlain ? word : "'" + word.replacingOccurrences(of: "'", with: "'\\''") + "'"
        }.joined(separator: " ")
    }
}
