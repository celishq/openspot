import Foundation

/// A tap of one modifier alone, such as Option: pressed and let go within `limit`, with no other key, modifier or click
/// between. A modifier held for a shortcut or a click is never a tap.
public struct ModifierTap: Sendable {
    public static let limit: TimeInterval = 0.5

    private var held: (modifier: Shortcut.Modifiers, at: TimeInterval)?
    private var isSpoiled = false

    public init() {}

    /// Takes the modifiers held after a change. It gives the modifier when a lone one is let go in time.
    public mutating func take(_ modifiers: Shortcut.Modifiers, at time: TimeInterval) -> Shortcut.Modifiers? {
        guard !modifiers.isEmpty else {
            defer {
                held = nil
                isSpoiled = false
            }
            guard let held, !isSpoiled, time - held.at <= Self.limit else { return nil }
            return held.modifier
        }
        if held == nil, !isSpoiled, modifiers.word != nil {
            held = (modifiers, time)
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
