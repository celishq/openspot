import Foundation

struct CallContext {
    let mac: Mac
    let api: CommandAPI
    let request: CommandRequest
    let places: AppPlaces
    let app: (any RunningApp)?
    let runs: SpotRuns?
    let account: Account?
    let secrets: SecretStore
    let trash: @Sendable (URL) throws -> URL
    let raise: (@Sendable (SpotEvent) async -> Void)?
    let caller: Spot?
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

    var isCareful: Bool {
        runs?.callers.isCareful == true
    }

    var careful: Set<SpotUse>? {
        isCareful ? Set(SpotUse.allCases) : nil
    }

    var fence: (caller: Spot, mode: CarefulMode)? {
        guard isCareful, let caller, !caller.uses.contains(.files) else { return nil }
        return (caller, CarefulMode(uses: caller.uses))
    }
}
