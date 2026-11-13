import Foundation

/// How a spot's script runs, as its header's `mode=` names it (protocol: Modes).
public enum SpotMode: String, CaseIterable, Equatable, Sendable {
    /// A process for each call.
    case once
    /// One process that takes each call on its standard input while something wants it.
    case stay
    /// One process from the start of the app to its quit.
    case always
    /// A JavaScript file that runs inside the app.
    case inline

    /// Whether the script stays running and takes calls on its standard input.
    public var stays: Bool {
        switch self {
        case .stay, .always: true
        case .once, .inline: false
        }
    }
}
