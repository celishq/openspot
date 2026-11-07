import Foundation

/// A key that a person assigned, which runs one command of a script from any app.
public struct GlobalKey: Hashable, Sendable {
    public let spot: String
    public let command: String
    public let shortcut: Shortcut

    public init(spot: String, command: String, shortcut: Shortcut) {
        self.spot = spot
        self.command = command
        self.shortcut = shortcut
    }

    /// The lines of this key in the config file.
    var text: String {
        "[[keys]]\nspot = \"\(spot)\"\ncommand = \"\(command)\"\nkey = \"\(shortcut.text)\""
    }
}
