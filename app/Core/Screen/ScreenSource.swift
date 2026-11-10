import Foundation

/// What a capture shows: a display, a window or an area, each fixed by a value or picked by the person (S2).
/// `any` lets the person pick a source of any kind.
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

    /// Reads one source word, such as `display`, `window:front` or `area:0,0,1/2,1`. Returns nil for anything else.
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

    /// The kind of a word and its value after the first colon. A colon with nothing after it is an empty value.
    static func split(_ word: String) -> (kind: String, value: String?) {
        guard let colon = word.firstIndex(of: ":") else { return (word, nil) }
        return (String(word[..<colon]), String(word[word.index(after: colon)...]))
    }
}
