import Foundation

/// What a call of the API changed in the config, so that the running app applies only that (A25).
public enum ConfigChange: Equatable, Sendable {
    /// The key of the panel or of a fix, or a key or a shake of a command or a float.
    case keys
    /// Spots that turned on or off, or that went into the menu bar or out of it.
    case spots([String])
    /// A value that a spot keeps, which the spot `caller` set, or a terminal with none.
    case value(spot: String, caller: String?)
}
