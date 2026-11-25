import Foundation

public final class CommandAPI: @unchecked Sendable {
    public typealias Work = @Sendable () async -> CommandAnswer

    let mac: Mac
    let access = KeptAccess()
    private let raise: (@Sendable (AppSignal) async -> Void)?
    private let app: (any RunningApp)?
    private let places: AppPlaces
    private let account: Account?
    private weak var runs: SpotRuns?
    private let calendar: CalendarCalls
    private let reminders: RemindersCalls
    private let nouns: [CommandNoun]

    public init(mac: Mac, places: AppPlaces, raise: (@Sendable (AppSignal) async -> Void)? = nil, app: (any RunningApp)? = nil, runs: SpotRuns? = nil, nouns: [CommandNoun] = CommandNoun.all) {
        self.mac = mac
        self.places = places
        account = app.map { app in Account(store: places.account, allows: { await app.allows($0) }) }
        self.runs = runs
        self.raise = raise
        self.app = app
        self.nouns = nouns
        calendar = CalendarCalls(mac: mac.calendar)
        reminders = RemindersCalls(mac: mac.reminders)
        runs?.callers.serve(by: self)
    }

    public func request(_ request: CommandRequest, from peer: pid_t, caller: SpotCaller? = nil) -> CommandRequest {
        guard let runs else { return request }
        var request = request
        request.caller = caller ?? runs.callers.caller(of: peer)
        request.isFromGroup = caller == nil
        return request
    }

    public func call(of request: CommandRequest) -> CommandLineCall? {
        let (spot, reason) = values(of: request)
        return CommandLineCall(arguments: request.arguments, spot: spot, reason: reason, nouns: nouns)
    }

    private func values(of request: CommandRequest) -> (spot: String?, reason: String?) {
        guard runs != nil else { return (places.environment[CallWords.spotVariable], nil) }
        let spot = request.caller?.spot.id
        return (spot?.isEmpty == false ? spot : nil, request.caller?.reason)
    }

    private func caller(of request: CommandRequest) -> Spot? {
        runs == nil ? nil : request.caller?.spot
    }

    public func admit(_ call: CommandLineCall, request: CommandRequest) -> CommandLineCall {
        guard !call.isFault, !call.rule.flags.contains(.reachesKey), let runs, let caller = caller(of: request) else { return call }
        if let refusal = call.rule.onlyPerson, !caller.isBuiltIn {
            return CommandLineCall(name: call.name, call: CallFault.refused("\(caller.name) \(refusal)"))
        }
        guard let needed = call.use else { return call }
        guard caller.uses.contains(needed.use) else {
            let refusal = UseRefusal(spot: caller, call: needed)
            Task { @MainActor in runs.refused(refusal) }
            return CommandLineCall(name: call.name, call: CallFault.undeclared(refusal))
        }
        Task { @MainActor in runs.used(needed, by: caller) }
        runs.usage.used(call.name, by: caller.id)
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
        if call.rule.flags.contains(.startsScripts), caller?.isBuiltIn != true, isSandboxed || caller != nil { return nil }
        let (spot, reason) = values(of: request)
        let work = call.call.work(in: CallContext(
            mac: mac, api: self, request: request, places: places, app: app, runs: runs, account: account, secrets: places.secrets, trash: places.trash, raise: raise, caller: caller,
            spot: spot, isInShow: reason != nil, input: input, output: output, calendar: calendar, reminders: reminders, nouns: nouns
        ))
        guard let work, let spotCaller = request.caller, caller != nil else { return work }
        return {
            let answer = await work()
            spotCaller.note(answer.code == 0 ? nil : answer.fix)
            return answer
        }
    }
}
