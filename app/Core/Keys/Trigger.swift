import Foundation

/// What a person gives a global key: a key with its modifiers, or a shake of the pointer (W2).
public enum Trigger: Hashable, Sendable {
    case key(Shortcut)
    case shake

    private static let shakeWord = "shake"

    /// Reads a key as a person writes it, such as ctrl+space, or the word shake.
    public init?(text: String) {
        if text.lowercased() == Self.shakeWord {
            self = .shake
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
        case .shake: Self.shakeWord
        }
    }

    /// The key as the Mac writes it, such as ⌃Space, or Shake.
    public var label: String {
        switch self {
        case .key(let shortcut): shortcut.label
        case .shake: "Shake"
        }
    }
}
