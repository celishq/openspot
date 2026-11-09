import Foundation

/// How a run reaches its script: a process for each call (01), or one process that stays (05). A link starts and ends the
/// processes, sends each call, says which frame answers what, and gives each frame and each end to its run. The run keeps
/// all that the spot shows.
@MainActor
protocol ScriptLink: AnyObject {
    var run: SpotRun? { get set }
    /// Whether a read or a search waits for its answer.
    var isAsking: Bool { get }
    /// Whether the link holds the script for a call of its own, such as a form or a call that waits for its `end`.
    var holdsScript: Bool { get }
    /// Whether the script can answer now.
    var isReachable: Bool { get }
    /// Sends a call, and returns whether the script got it.
    @discardableResult
    func send(_ call: SpotRun.Call) -> Bool
    /// Asks for the form of an action, and returns the frame with its fields, or nil when there is none to wait for.
    func form(_ action: SpotAction, key: String) async throws -> String?
    /// Gives a filled form to the script, and returns all that it printed, or nil when a person stopped it.
    func submit(_ action: SpotAction, key: String, values: String) async throws -> String?
    func stop(_ call: ScriptCall)
    /// Starts the script that something wants, and ends the one that nothing wants.
    func settle()
    /// Ends the script and each of its calls, which then change nothing.
    func end()
    /// Lets go of the script as the app quits, which ends its processes itself.
    func leave()
    /// A scan looked at the folder: a stopped script that changed can start again (Y5).
    func scanned()
}
