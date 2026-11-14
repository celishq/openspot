import Foundation

public enum Trigger: Hashable, Sendable {
    case key(Shortcut)
    case tap(Shortcut.Modifiers)
    case shake

    private static let shakeWord = "shake"

    public init?(text: String) {
        if text.lowercased() == Self.shakeWord {
            self = .shake
        } else if let modifier = Shortcut.Modifiers(word: text) {
            self = .tap(modifier)
        } else if let shortcut = Shortcut(text: text) {
            self = .key(shortcut)
        } else {
            return nil
        }
    }

    public var text: String {
        switch self {
        case .key(let shortcut): shortcut.text
        case .tap(let modifier): modifier.word ?? ""
        case .shake: Self.shakeWord
        }
    }

    public var label: String {
        switch self {
        case .key(let shortcut): shortcut.label
        case .tap(let modifier): modifier.label ?? ""
        case .shake: "Shake"
        }
    }
}
