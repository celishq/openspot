import Foundation

/// What the API asks of the app that runs. A process with no app to reach has none, so each call that needs one fails.
public protocol RunningApp: Sendable {
    /// Takes a change that the API wrote to the config, such as a spot turned on or a key, so that the grid and the keys
    /// follow it at once, and nothing else changes (A25).
    func configChanged(_ change: ConfigChange) async
    /// The version of a downloaded update that waits to install, the number of calls that a restart would stop, and
    /// whether the app runs for the first time.
    func status() async -> (update: String?, calls: Int, isFirstLaunch: Bool)
    /// Asks for a new version now. Returns false for a copy of the app that does not update itself.
    func checkUpdate() async -> Bool
    /// Restarts into the downloaded update. Returns false when none waits.
    func installUpdate() async -> Bool
    func quit() async
    /// Opens the panel on the first sheet of a spot as a new flow. Returns false when no spot has that ID.
    func open(_ id: String) async -> Bool
    /// Pushes a sheet of a spot, or a page of it, over the flow that shows (protocol: Pages). Returns false when no spot has
    /// that ID.
    func push(_ id: String, page: String?, title: String?, replace: Bool) async -> Bool
    /// Pops the sheet of a spot that shows, or with `all` goes back to its first sheet (protocol: Pages). Returns false when
    /// it moves nothing.
    func pop(_ id: String, all: Bool) async -> Bool
    /// Shows the whole text of a spot that comes with the app, and what of it runs by itself. Returns false when no such
    /// spot has that ID.
    func review(_ id: String) async -> Bool
    /// Does what the row of a card's actions menu does to a spot. Returns false when no card has that ID.
    func act(_ act: CardAct, on id: String) async -> Bool
    /// Asks the person for files for a spot that takes them, and drops the chosen ones on it. Returns false when no such
    /// spot has that ID.
    func choose(for id: String) async -> Bool
    /// Opens the panel in Edit Spots with the store.
    func openStore() async
    /// Opens the panel with the card of a spot selected. Returns false when no card has that ID.
    func reveal(_ id: String) async -> Bool
    /// Opens the sandbox window on a file, or on typed text with none, and returns once the person closes it. A script that
    /// it runs runs in Careful mode when `isCareful` (protocol: Trust).
    func sandbox(_ file: URL?, isCareful: Bool) async
    /// Runs the action of a spot's setting, as Enter on its row does: its form shows in the panel, and the panel closes when
    /// it is done. Returns false when no spot has that ID.
    func changeSetting(_ key: String, of spot: String) async -> Bool
    /// Asks for Touch ID or the Mac password, and returns whether the person passed.
    func allows(_ reason: String) async -> Bool
}
