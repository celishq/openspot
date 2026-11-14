import Foundation

public enum ScreenSource: Equatable, Sendable {
    public enum Window: Equatable, Sendable {
        case front
        case id(UInt32)
    }

    case any
    case display(UInt32?)
    case window(Window?)
    case area(WindowMove?)

    static let kinds: Set<String> = ["display", "window", "area"]

    init?(word: String) {
        let (kind, value) = Self.split(word)
        switch (kind, value) {
        case ("display", nil): self = .display(nil)
        case ("display", let value?):
            guard let id = UInt32(value) else { return nil }
            self = .display(id)
        case ("window", nil): self = .window(nil)
        case ("window", "front"): self = .window(.front)
        case ("window", let value?):
            guard let id = UInt32(value) else { return nil }
            self = .window(.id(id))
        case ("area", nil): self = .area(nil)
        case ("area", let value?):
            let values = value.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard values.count == 4, let frame = WindowMove(words: [values.joined(separator: " ")]) else { return nil }
            self = .area(frame)
        default: return nil
        }
    }

    static func split(_ word: String) -> (kind: String, value: String?) {
        guard let colon = word.firstIndex(of: ":") else { return (word, nil) }
        return (String(word[..<colon]), String(word[word.index(after: colon)...]))
    }
}
