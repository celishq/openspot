import Foundation

public final class CommandAPI: @unchecked Sendable {
    public typealias Work = @Sendable () async -> CommandAnswer

    private let mac: Mac
    private let raise: (@Sendable (SpotEvent) async -> Void)?
    private let app: (any RunningApp)?
    private let places: AppPlaces
    private let account: Account?
    private weak var runs: SpotRuns?
    private let calendar: CalendarCalls
    private let reminders: RemindersCalls
    private let rates: CalcRateCache
    private let nouns: [CommandNoun]

    public init(mac: Mac, places: AppPlaces, raise: (@Sendable (SpotEvent) async -> Void)? = nil, app: (any RunningApp)? = nil, runs: SpotRuns? = nil, rates: CalcRateCache, nouns: [CommandNoun] = CommandNoun.all) {
        self.mac = mac
        self.places = places
        account = app.map { app in Account(store: places.account, allows: { await app.allows($0) }) }
        self.runs = runs
        self.raise = raise
        self.app = app
        self.rates = rates
        self.nouns = nouns
        calendar = CalendarCalls(mac: mac.calendar)
        reminders = RemindersCalls(mac: mac.reminders)
    }

    public func request(_ request: CommandRequest, from peer: pid_t) -> CommandRequest {
        guard let runs else { return request }
        var request = request
        (request.token, request.isBound) = runs.tokens.token(of: peer, claimed: request.token)
        return request
    }

    public func call(of request: CommandRequest) -> CommandLineCall? {
        let (spot, reason) = values(of: request)
        return CommandLineCall(arguments: request.arguments, spot: spot, reason: reason, nouns: nouns)
    }

    private func values(of request: CommandRequest) -> (spot: String?, reason: String?) {
        let variables = runs.map { $0.tokens.variables(of: request.token) } ?? places.environment
        return (variables[CallWords.spotVariable], variables[CallWords.reasonVariable])
    }

    private func caller(of request: CommandRequest) -> CallerTokens.Caller? {
        runs?.tokens.caller(of: request.token)
    }

    public func admit(_ call: CommandLineCall, request: CommandRequest) -> CommandLineCall {
        guard !call.isFault, !call.rule.flags.contains(.reachesKey), let runs, let caller = caller(of: request) else { return call }
        if let refusal = call.rule.onlyPerson, !caller.isBuiltIn {
            return CommandLineCall(name: call.name, call: CallFault.refused("\(caller.name) \(refusal)"))
        }
        guard let needed = call.use else { return call }
        if runs.tokens.isCareful, !caller.uses.contains(needed.use) {
            return CommandLineCall(name: call.name, call: CallFault.refused("Careful mode stopped \(caller.name), because it \(needed.words) without `uses=\(needed.use.rawValue)` in its header. Add it, or turn Careful mode off."))
        }
        Task { @MainActor in runs.used(needed, by: caller) }
        return call
    }

    public func work(for request: CommandRequest, input: @escaping @Sendable () async -> String, isSandboxed: Bool = false, output: CommandOutput? = nil) -> Work? {
        guard let call = call(of: request) else { return nil }
        return work(for: admit(call, request: request), request: request, input: input, isSandboxed: isSandboxed, output: output)
    }

    public func work(for call: CommandLineCall, request: CommandRequest, input: @escaping @Sendable () async -> String, isSandboxed: Bool = false, output: CommandOutput? = nil) -> Work? {
        guard let output else {
            let kept = CommandOutput()
            guard let work = work(for: call, request: request, input: input, isSandboxed: isSandboxed, output: kept) else { return nil }
            return { kept.answer(ending: await work()) }
        }
        let caller = caller(of: request)
        if call.rule.flags.contains(.startsScripts), isSandboxed || runs?.tokens.isCareful == true && caller != nil { return nil }
        let (spot, reason) = values(of: request)
        let work = call.call.work(in: CallContext(
            mac: mac, api: self, request: request, environment: places.environment, app: app, runs: runs, account: account, secrets: places.secrets, raise: raise, caller: caller,
            spot: spot, isRead: reason != nil, input: input, output: output, calendar: calendar, reminders: reminders, rates: rates, nouns: nouns
        ))
        guard let work, let tokens = runs?.tokens, let token = request.token, caller != nil else { return work }
        return {
            let answer = await work()
            tokens.note(answer.code == 0 ? nil : answer.fix, of: token)
            return answer
        }
    }
}
