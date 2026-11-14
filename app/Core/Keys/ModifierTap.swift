import Foundation

/// A tap of one modifier alone, such as Option: pressed and let go within `limit`, with no other key, modifier or click
/// between. A modifier held for a shortcut or a click is never a tap, also when another app caught the key, as a hotkey
/// does, so that only the count of keys that went down shows it.
public struct ModifierTap: Sendable {
    public static let limit: TimeInterval = 0.5

    private var held: (modifier: Shortcut.Modifiers, at: TimeInterval, keysDown: UInt32?)?
    private var isSpoiled = false

    public init() {}

    /// Takes the modifiers held after a change, with the count of keys that went down on the Mac so far when it is known.
    /// It gives the modifier when a lone one is let go in time, and no key went down while it was held.
    public mutating func take(_ modifiers: Shortcut.Modifiers, at time: TimeInterval, keysDown: UInt32? = nil) -> Shortcut.Modifiers? {
        guard !modifiers.isEmpty else {
            defer {
                held = nil
                isSpoiled = false
            }
            guard let held, !isSpoiled, time - held.at <= Self.limit else { return nil }
            if let before = held.keysDown, let keysDown, keysDown != before { return nil }
            return held.modifier
        }
        if held == nil, !isSpoiled, modifiers.word != nil {
            held = (modifiers, time, keysDown)
        } else if held?.modifier != modifiers {
            isSpoiled = true
        }
        return nil
    }

    /// Takes a key or a click, which makes the held modifier part of a shortcut.
    public mutating func spoil() {
        if held != nil { isSpoiled = true }
    }
}
