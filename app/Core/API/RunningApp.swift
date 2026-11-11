import Foundation

/// What the API asks of the app that runs. A process with no app to reach has none, so each call that needs one fails.
public protocol RunningApp: Sendable {
    /// Takes a change that the API wrote to the config, such as a spot turned on or a key, so that the grid and the keys
    /// follow it at once.
    func configChanged() async
}
