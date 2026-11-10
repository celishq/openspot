import Foundation

/// A key or a shake that a person assigned, which floats its spot or runs one command of its script, from any app (W1, W2).
public struct GlobalKey: Hashable, Sendable {
    /// What the key does: float its spot, or run one command of its script.
    public enum Act: Hashable, Sendable {
        case float
        case command(String)
    }

    public let spot: String
    public let act: Act
    public let trigger: Trigger

    public init(spot: String, act: Act, trigger: Trigger) {
        self.spot = spot
        self.act = act
        self.trigger = trigger
    }

    public init(spot: String, command: String, shortcut: Shortcut) {
        self.init(spot: spot, act: .command(command), trigger: .key(shortcut))
    }

    /// The lines of this key in the config file. A key with no command line floats its spot.
    var text: String {
        let command = if case .command(let id) = act { "command = \"\(id)\"\n" } else { "" }
        return "[[keys]]\nspot = \"\(spot)\"\n\(command)key = \"\(trigger.text)\""
    }
}
