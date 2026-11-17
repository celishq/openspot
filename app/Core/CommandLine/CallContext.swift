import Foundation

struct CallContext {
    let mac: Mac
    let api: CommandAPI
    let request: CommandRequest
    let environment: [String: String]
    let app: (any RunningApp)?
    let runs: SpotRuns?
    let account: Account?
    let secrets: SecretStore
    let raise: (@Sendable (SpotEvent) async -> Void)?
    let caller: CallerTokens.Caller?
    let spot: String?
    let isRead: Bool
    let input: @Sendable () async -> String
    let output: CommandOutput
    let calendar: CalendarCalls
    let reminders: RemindersCalls
    let rates: CalcRateCache
    let nouns: [CommandNoun]

    var usage: String {
        CommandLineCall.usage(of: nouns)
    }

    var folder: URL {
        request.place
    }

    var keyCaller: CallerTokens.Caller? {
        request.isBound ? caller : nil
    }

    var fence: (caller: CallerTokens.Caller, mode: Sandbox)? {
        guard let caller, caller.isRestricted, !caller.uses.contains(.files) else { return nil }
        return (caller, Sandbox(uses: caller.uses))
    }
}
