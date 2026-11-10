import Foundation

/// A key or a shake that a person assigned, which runs one command of a script from any app, or with no command floats its
/// spot (W1, W2).
public struct GlobalKey: Hashable, Sendable {
    public let spot: String
    public let command: String?
    public let trigger: Trigger

    public init(spot: String, command: String?, trigger: Trigger) {
        self.spot = spot
        self.command = command
        self.trigger = trigger
    }

    public init(spot: String, command: String?, shortcut: Shortcut) {
        self.init(spot: spot, command: command, trigger: .key(shortcut))
    }

    /// The lines of this key in the config file.
    var text: String {
        "[[keys]]\nspot = \"\(spot)\"\n" + (command.map { "command = \"\($0)\"\n" } ?? "") + "key = \"\(trigger.text)\""
    }
}
