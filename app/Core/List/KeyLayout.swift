import Foundation
import Synchronization

/// The character that each key of a keyboard layout types with no modifier, by key code.
public struct KeyLayout: Equatable, Sendable {
    public let keys: [UInt16: Character]
    private let codes: [Character: UInt16]

    public init(keys: [UInt16: Character]) {
        self.keys = keys
        codes = Dictionary(keys.map { ($1, $0) }, uniquingKeysWith: min)
    }

    private static let current = Mutex<[KeyLayout]>([])

    /// The layouts that the person turned on. The app sets them as it starts and each time they change.
    public static var enabled: [KeyLayout] {
        get { current.withLock { $0 } }
        set { current.withLock { $0 = newValue } }
    }

    /// The text that the same keys type in another layout, or nil when a character of it is on no key of this one.
    func text(_ text: String, in other: KeyLayout) -> String? {
        var typed = ""
        for character in text.lowercased() {
            if character.isWhitespace {
                typed.append(character)
                continue
            }
            guard let code = codes[character], let other = other.keys[code] else { return nil }
            typed.append(other)
        }
        return typed
    }
}
