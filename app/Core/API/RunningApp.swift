import Foundation

/// What the API asks of the app that runs. A process with no app to reach has none, so each call that needs one fails.
public protocol RunningApp: Sendable {
    /// Takes a change that the API wrote to the config, such as a spot turned on or a key, so that the grid and the keys
    /// follow it at once.
    func configChanged() async
    /// The version of a downloaded update that waits to install, the number of calls that a restart would stop, and
    /// whether the app runs for the first time.
    func status() async -> (update: String?, calls: Int, isFirstLaunch: Bool)
    /// Asks for a new version now. Returns false for a copy of the app that does not update itself.
    func checkUpdate() async -> Bool
    /// Restarts into the downloaded update. Returns false when none waits.
    func installUpdate() async -> Bool
    func quit() async
}
