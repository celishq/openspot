import Foundation

/// What a person gives a global key: a key with its modifiers, a tap of one modifier alone, or a shake of the pointer (W2).
public enum Trigger: Hashable, Sendable {
    case key(Shortcut)
    case tap(Shortcut.Modifiers)
    case shake

    private static let shakeWord = "shake"

    /// Reads a key as a person writes it, such as ctrl+space, one modifier, such as option, or the word shake.
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

    /// The words for the config file.
    public var text: String {
        switch self {
        case .key(let shortcut): shortcut.text
        case .tap(let modifier): modifier.word ?? ""
        case .shake: Self.shakeWord
        }
    }

    /// The key as the Mac writes it, such as ⌃Space, ⌥ Option, or Shake.
    public var label: String {
        switch self {
        case .key(let shortcut): shortcut.label
        case .tap(let modifier): modifier.label ?? ""
        case .shake: "Shake"
        }
    }
}
