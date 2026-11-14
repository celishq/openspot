import Foundation

/// The work of each `openspot <noun> <verb>` that Core does. The app gives it over its socket, and a process of its own
/// gives the same answer when the app does not run (protocol: The openspot command). It hands each call to the calls of its noun, and keeps the
/// stores of the Mac and the keyword files across calls, so that the app answers each later call from them.
public final class CommandAPI: @unchecked Sendable {
    public typealias Work = @Sendable () async -> CommandAnswer

    private let mac: any Mac
    /// Raises an event in the running app, or nil in a process with no app to reach.
    private let raise: (@Sendable (SpotEvent) async -> Void)?
    private let app: (any RunningApp)?
    /// The runs of the app, which know each spot's call by its token, or nil in a process with no app to reach (protocol: Trust).
    private weak var runs: SpotRuns?
    private let calendar: CalendarCalls
    private let reminders: RemindersCalls
    private let keywords = GlyphKeywordCache()

    public init(mac: any Mac, raise: (@Sendable (SpotEvent) async -> Void)? = nil, app: (any RunningApp)? = nil, runs: SpotRuns? = nil) {
        self.mac = mac
        self.runs = runs
        self.raise = raise
        self.app = app
        calendar = CalendarCalls(mac: mac)
        reminders = RemindersCalls(mac: mac)
    }

    /// The environment of a call from a process: with the token, the ID and the reason of the spot whose process group
    /// holds it, by the app's own record, and as it came for any other process (protocol: Trust).
    public func environment(of peer: pid_t, over environment: [String: String]) -> [String: String] {
        runs?.tokens.environment(of: peer, over: environment) ?? environment
    }

    /// The call as it may run, after a look at its caller. A spot never changes Careful mode, and while that mode is on, a
    /// spot's call of a use that its header does not name is refused (protocol: Trust). Else a spot's call of a use is told to the runs,
    /// so that an undeclared one shows (protocol: Trust). The person's call passes as it is.
    public func admit(_ call: CommandLineCall, arguments: [String], environment: [String: String]) -> CommandLineCall {
        switch call {
        case .refused, .unknown: return call
        default: break
        }
        if case .account(let account) = call, account.reachesKey {
            let caller = runs?.tokens.caller(of: environment)
            guard caller?.reachesAccountKey == true else { return .refused("Only Openspot's Account spot can reach your account key.") }
            return call
        }
        guard let runs, let caller = runs.tokens.caller(of: environment) else { return call }
        if case .appCareful = call, !caller.isBuiltIn {
            return .refused("\(caller.name) cannot change Careful mode. Only you can, in Settings or with `openspot setting set --spot openspot careful true` in Terminal.")
        }

        guard let needed = SpotUseCall(arguments: arguments, of: caller.id) else { return call }
        if runs.tokens.isCareful, !caller.uses.contains(needed.use) {
            return .refused("Careful mode stopped \(caller.name), because it \(needed.words) without `uses=\(needed.use.rawValue)` in its header. Add it, or turn Careful mode off.")
        }
        Task { @MainActor in runs.used(needed, by: caller) }
        return call
    }

    /// The work that answers a call, or nil for a call that runs in a process of its own: one that draws a picture or runs
    /// a helper, or a show or a sandbox with no app to reach, and a call that starts scripts for a caller in a sandbox, such
    /// as a spot in Careful mode, whose process of its own then keeps that sandbox (protocol: Trust). `input` reads stdin, and only a call that takes stdin reads it. `isPiped` says
    /// whether stdin is a pipe or a file, which `spot run` passes on, and `isSandboxed` whether the caller runs in a sandbox. A call prints to `output` as it runs, and with none,
    /// its answer holds all that it printed.
    public func work(for call: CommandLineCall, input: @escaping @Sendable () async -> String, environment: [String: String], isPiped: Bool = true, isSandboxed: Bool = false, output: CommandOutput? = nil) -> Work? {
        guard let output else {
            let kept = CommandOutput()
            guard let work = work(for: call, input: input, environment: environment, isPiped: isPiped, isSandboxed: isSandboxed, output: kept) else { return nil }
            return { kept.answer(ending: await work()) }
        }
        let isRead = environment["OPENSPOT_REASON"] != nil
        let spots = SpotCalls(environment: environment, app: app, runs: runs)
        let settings = SettingCalls(environment: environment, app: app)
        let keys = KeyCalls(environment: environment, app: app)
        let apps = AppCalls(mac: mac, environment: environment, app: app)
        let clipboard = ClipboardCalls(mac: mac, environment: environment)
        let screen = ScreenCalls(mac: mac, environment: environment, fence: fence(of: environment))
        if Self.startsScripts(call), isSandboxed || runs?.tokens.isCareful == true && runs?.tokens.caller(of: environment) != nil { return nil }
        switch call {
        case .help: return HelpCalls().list()
        case .guideOf(let noun): return HelpCalls().guide(of: noun)
        case .unknown(let words): return { CommandAnswer(errors: "openspot cannot do this: \(words)\n\n\(CommandLineCall.usage)", code: 2) }
        case .refused(let line): return { CommandAnswer(errors: "\(line)\n", code: 1) }
        case .guide: return GuideCalls(mac: mac).text()
        case .promptNew(let words): return PromptCalls(mac: mac, environment: environment).new(words)
        case .checkSheet: return CheckCalls(input: input, environment: environment).sheet()
        case .check(let path): return CheckCalls(input: input, environment: environment, tokens: runs?.tokens).folder(path, json: false, careful: fence(environment))
        case .checkJSON(let path): return CheckCalls(input: input, environment: environment, tokens: runs?.tokens).folder(path, json: true, careful: fence(environment))
        case .spotRun(let id, let arguments): return spots.run(id, arguments, input: isPiped ? input : nil, careful: fence(environment), output: output)
        case .spotShow(let id): return spots.show(id)
        case .sandbox(let path): return SandboxCalls(environment: environment, app: app).open(path, isCareful: runs?.tokens.isCareful == true)
        case .settingGet(let spot, let key): return settings.get(key, of: spot)
        case .settingSet(let spot, let key, let value): return settings.set(key, of: spot, to: value)
        case .settingList(let frame): return settings.list(frame: frame)
        case .batch: return BatchCalls(api: self, environment: environment).run(input, output: output)
        case .settingChange(let spot, let key): return settings.change(key, of: spot)
        case .spotList(let core, let frame): return spots.list(core: core, frame: frame)
        case .spotTurn(let ids, let isOn): return spots.turn(ids, on: isOn)
        case .spotAdd(let source?, let isConfirmed): return spots.add(source, isConfirmed: isConfirmed)
        case .spotAdd(nil, let isConfirmed): return spots.restore(isConfirmed: isConfirmed)
        case .spotRemove(let id): return spots.remove(id)
        case .spotOpen(let id): return spots.open(id)
        case .spotChoose(let id): return spots.choose(for: id)
        case .spotAct(let act, let id): return spots.act(act, id)
        case .spotReview(let id): return spots.review(id)
        case .gridEdit: return spots.editGrid()
        case .spotNew(let name, let starter): return spots.new(name, from: starter)
        case .spotLog(let id): return spots.log(id)
        case .spotStats(let days, let spot, let format): return spots.stats(days: days, spot: spot, format: format)
        case .appKeySet(let name, let key): return keys.set(app: name, to: key)
        case .keySet(let spot, let act, let key): return keys.set(act, of: spot, to: key)
        case .menuBar(let id, let isShown): return MenuBarCalls(environment: environment, app: app).show(id, isShown)
        case .appStatus(let frame): return apps.status(frame: frame)
        case .appLogin(let isOn): return apps.login(isOn)
        case .appLink(let isOn): return apps.link(isOn)
        case .appCareful(let isOn): return apps.careful(isOn)
        case .appQuit: return apps.quit()
        case .updateCheck: return UpdateCalls(app: app).check()
        case .updateInstall: return UpdateCalls(app: app).install()
        case .account(let call): return AccountCalls(environment: environment, app: app).work(for: call, input: input)
        case .eventEmit(let name, let value): return EventCalls(raise: raise).emit(name, value: value)
        case .calcSolve(let words): return CalcCalls().solve(words)
        case .emoji(let tone): return EmojiCalls(keywords: keywords).rows(tone: tone)
        case .symbols: return SymbolsCalls(keywords: keywords).rows()
        case .calendarEvents(let days, let hidden): return calendar.events(days: days, hiding: hidden, isRead: isRead)
        case .calendarCalendars: return calendar.calendars(isRead: isRead)
        case .calendarAdd(let words, let isDry): return calendar.add(words, isDry: isDry, isRead: isRead)
        case .calendarShow(let id): return calendar.show(id, isRead: isRead)
        case .remindersDue(let days, let hidden): return reminders.due(days: days, hiding: hidden, isRead: isRead)
        case .remindersLists: return reminders.lists(isRead: isRead)
        case .remindersAdd(let words, let isDry): return reminders.add(words, isDry: isDry, isRead: isRead)
        case .remindersDone(let id, let isDone): return reminders.done(id, isDone, isRead: isRead)
        case .remindersShow(let id): return reminders.show(id, isRead: isRead)
        case .clipboardCopy(let path): return clipboard.copy(path, input: input)
        case .clipboardRead: return clipboard.read()
        case .clipboardPaste: return clipboard.paste()
        case .windowFrame: return CommandAnswer.work { [mac] in try await mac.windowFrame() }
        case .windowMove(let move): return CommandAnswer.work { [mac] in
            try await mac.moveWindow(move)
            return ""
        }
        case .screenSources: return screen.sources()
        case .screenShot(let capture): return screen.shot(capture)
        case .screenRecordStart(let capture): return screen.start(capture)
        case .screenRecordStop: return screen.stop()
        case .screenRecordStatus: return screen.status()
        case .translate(let from, let to): return CommandAnswer.work { [mac] in try await mac.translate(await input(), from: from, to: to) }
        case .translateLanguages: return { [mac] in CommandAnswer(output: await mac.translationLanguages()) }
        case .colorPick: return { [mac] in CommandAnswer(output: await mac.pickColor()) }
        case .folderPick: return { [mac] in CommandAnswer(output: await mac.pickFolder()) }
        case .renderSpot, .render, .renderCard, .renderPanel, .helper, .glyphBook:
            return nil
        }
    }

    /// Whether a call starts scripts or a window, which a caller in a sandbox runs in a process of its own (protocol: Trust).
    private static func startsScripts(_ call: CommandLineCall) -> Bool {
        switch call {
        case .check, .checkJSON, .spotRun, .sandbox: true
        default: false
        }
    }

    /// The most uses that Careful mode leaves the scripts that the person's call starts: each spot's own. Nil when Careful
    /// mode is off (protocol: Trust).
    private func fence(_ environment: [String: String]) -> Set<SpotUse>? {
        runs?.tokens.isCareful == true ? Set(SpotUse.allCases) : nil
    }

    /// The spot that calls and its Careful mode, when that mode keeps it from writing outside its own folders (protocol: Trust).
    private func fence(of environment: [String: String]) -> (caller: CallerTokens.Caller, mode: CarefulMode)? {
        guard let runs, runs.tokens.isCareful, let caller = runs.tokens.caller(of: environment), !caller.uses.contains(.files) else { return nil }
        return (caller, CarefulMode(uses: caller.uses))
    }
}
