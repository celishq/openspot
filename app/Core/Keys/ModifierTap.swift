import Foundation

public struct ModifierTap: Sendable {
    public static let limit: TimeInterval = 0.5

    private var held: (modifier: Shortcut.Modifiers, at: TimeInterval, keysDown: UInt32?)?
    private var isSpoiled = false

    public init() {}

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

    public mutating func spoil() {
        if held != nil { isSpoiled = true }
    }
}
