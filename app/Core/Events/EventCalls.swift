import Foundation

struct EventCalls {
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
