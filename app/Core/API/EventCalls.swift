import Foundation

/// The call of `openspot event emit`: an event raised in the running app (protocol: Events).
struct EventCalls {
    /// Raises an event in the running app, or nil in a process with no app to reach.
    let raise: (@Sendable (SpotEvent) async -> Void)?

    func emit(_ name: String, value: String?) -> CommandAPI.Work {
        guard let raise else {
            return { CommandAnswer(errors: "Openspot is not running, so no spot hears `\(name)`. Open Openspot, then run this again.\n", code: 1) }
        }
        return {
            await raise(.named(name, value: value))
            return CommandAnswer()
        }
    }
}
