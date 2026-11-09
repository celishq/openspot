import Foundation

/// A picture or a recording that `openspot screen` was asked for: its source, its inputs, its options and its file.
public struct ScreenCapture: Equatable, Sendable {
    public var source: ScreenSource
    public var inputs: [ScreenInput]
    public var cursor: Bool
    /// The file of the pointer and key log of a recording (S5).
    public var events: String?
    public var file: String?

    public init(source: ScreenSource = .any, inputs: [ScreenInput] = [], cursor: Bool = false, events: String? = nil, file: String? = nil) {
        self.source = source
        self.inputs = inputs
        self.cursor = cursor
        self.events = events
        self.file = file
    }

    /// Reads the words after the verb, in any order. Inputs and `--events` belong to a recording. A word of a known kind
    /// with a bad value is refused, not taken for a file. Returns nil for anything else.
    public init?(words: [String], records: Bool) {
        self.init()
        var words = words[...]
        var source: ScreenSource?
        while let word = words.popFirst() {
            let kind = ScreenSource.split(word).kind
            if word == "--cursor" {
                guard !cursor else { return nil }
                cursor = true
            } else if word == "--events", records {
                guard events == nil, let path = words.popFirst() else { return nil }
                events = path
            } else if word.hasPrefix("-") {
                return nil
            } else if ScreenSource.kinds.contains(kind) {
                guard source == nil, let found = ScreenSource(word: word) else { return nil }
                source = found
            } else if ScreenInput.kinds.contains(kind) {
                guard records, let input = ScreenInput(word: word), !inputs.contains(where: { $0.kind == input.kind }) else { return nil }
                inputs.append(input)
            } else {
                guard file == nil else { return nil }
                file = word
            }
        }
        self.source = source ?? .any
    }
}
