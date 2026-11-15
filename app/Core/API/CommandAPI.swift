import Foundation

public final class CommandAPI: @unchecked Sendable {
    public typealias Work = @Sendable () async -> CommandAnswer

    private let mac: any Mac
    private let raise: (@Sendable (SpotEvent) async -> Void)?
    private let app: (any RunningApp)?
    private let places: AppPlaces
    private let account: Account?
    private weak var runs: SpotRuns?
    private let calendar: CalendarCalls
    private let reminders: RemindersCalls
    private let keywords = GlyphKeywordCache()

    public init(mac: any Mac, places: AppPlaces, raise: (@Sendable (SpotEvent) async -> Void)? = nil, app: (any RunningApp)? = nil, runs: SpotRuns? = nil) {
        self.mac = mac
        self.places = places
        account = app.map { app in Account(store: places.account, allows: { await app.allows($0) }) }
        self.runs = runs
        self.raise = raise
        self.app = app
        calendar = CalendarCalls(mac: mac)
        reminders = RemindersCalls(mac: mac)
    }

    public func request(_ request: CommandRequest, from peer: pid_t) -> CommandRequest {
        guard let runs else { return request }
        var request = request
        (request.token, request.isBound) = runs.tokens.token(of: peer, claimed: request.token)
        return request
    }

    public func call(of request: CommandRequest) -> CommandLineCall? {
        CommandLineCall(arguments: request.arguments, environment: variables(of: request))
    }

    private func variables(of request: CommandRequest) -> [String: String] {
        guard let runs else { return places.environment }
        return runs.tokens.variables(of: request.token)
    }

    private func caller(of request: CommandRequest) -> CallerTokens.Caller? {
        runs?.tokens.caller(of: request.token)
    }

    public func admit(_ call: CommandLineCall, request: CommandRequest) -> CommandLineCall {
        switch call {
        case .refused, .unknown: return call
        case .account(let account) where account.reachesKey: return call
        case .storePublish: return call
        default: break
        }
        guard let runs, let caller = caller(of: request) else { return call }
        if case .appCareful = call, !caller.isBuiltIn {
            return .refused("\(caller.name) cannot change Careful mode. Only you can, in Settings or with `openspot setting set --spot openspot careful true` in Terminal.")
        }

        guard let needed = SpotUseCall(arguments: request.arguments, of: caller.id) else { return call }
        if runs.tokens.isCareful, !caller.uses.contains(needed.use) {
            return .refused("Careful mode stopped \(caller.name), because it \(needed.words) without `uses=\(needed.use.rawValue)` in its header. Add it, or turn Careful mode off.")
        }
        Task { @MainActor in runs.used(needed, by: caller) }
        return call
    }

    public func work(for call: CommandLineCall, request: CommandRequest, input: @escaping @Sendable () async -> String, isSandboxed: Bool = false, output: CommandOutput? = nil) -> Work? {
        guard let output else {
            let kept = CommandOutput()
            guard let work = work(for: call, request: request, input: input, isSandboxed: isSandboxed, output: kept) else { return nil }
            return { kept.answer(ending: await work()) }
        }
        let environment = places.environment
        let folder = request.place
        let caller = caller(of: request)
        let keyCaller = request.isBound ? caller : nil
        let variables = variables(of: request)
        let isRead = variables["OPENSPOT_REASON"] != nil
        let isPiped = request.isPiped
        let spots = SpotCalls(environment: environment, folder: folder, app: app, runs: runs)
        let settings = SettingCalls(environment: environment, caller: variables["OPENSPOT_ID"], app: app)
        let keys = KeyCalls(environment: environment, app: app)
        let apps = AppCalls(mac: mac, environment: environment, app: app)
        let clipboard = ClipboardCalls(mac: mac, folder: folder)
        let screen = ScreenCalls(mac: mac, folder: folder, fence: fence(of: caller))
        if Self.startsScripts(call), isSandboxed || runs?.tokens.isCareful == true && caller != nil { return nil }
        switch call {
        case .help: return HelpCalls().list()
        case .guideOf(let noun): return HelpCalls().guide(of: noun)
        case .unknown(let words): return { CommandAnswer(errors: "openspot cannot do this: \(words)\n\n\(CommandLineCall.usage)", code: 2) }
        case .refused(let line): return { CommandAnswer(errors: "\(line)\n", code: 1) }
        case .guide: return GuideCalls(mac: mac).text()
        case .promptNew(let words): return PromptCalls(mac: mac, environment: environment).new(words)
        case .promptChange(let id, let words, let failure): return PromptCalls(mac: mac, environment: environment).change(id, words: words, failure: failure)
        case .checkSheet: return CheckCalls(input: input, environment: environment, place: folder).sheet()
        case .check(let path): return CheckCalls(input: input, environment: environment, place: folder, tokens: runs?.tokens).folder(path, json: false, careful: fence)
        case .checkJSON(let path): return CheckCalls(input: input, environment: environment, place: folder, tokens: runs?.tokens).folder(path, json: true, careful: fence)
        case .spotRun(let id, let arguments): return spots.run(id, arguments, input: isPiped ? input : nil, careful: fence, output: output)
        case .spotShow(let id): return spots.show(id)
        case .sandbox(let path): return SandboxCalls(folder: folder, app: app).open(path, isCareful: runs?.tokens.isCareful == true)
        case .settingGet(let spot, let key): return settings.get(key, of: spot)
        case .settingSet(let spot, let key, let value): return settings.set(key, of: spot, to: value)
        case .settingList(let frame): return settings.list(frame: frame)
        case .batch: return BatchCalls(api: self, request: request).run(input, output: output)
        case .settingChange(let spot, let key): return settings.change(key, of: spot)
        case .spotList(let core, let frame): return spots.list(core: core, frame: frame)
        case .spotTurn(let ids, let isOn): return spots.turn(ids, on: isOn)
        case .spotAdd(let source?, let isConfirmed): return spots.add(source, isConfirmed: isConfirmed)
        case .spotAdd(nil, let isConfirmed): return spots.restore(isConfirmed: isConfirmed)
        case .spotRemove(let id): return spots.remove(id)
        case .spotOpen(let id): return spots.open(id)
        case .spotPush(let id, let page, let title, let replace): return spots.push(id, page: page, title: title, replace: replace)
        case .spotPop(let id, let all): return spots.pop(id, all: all)
        case .spotChoose(let id): return spots.choose(for: id)
        case .spotAct(let act, let id): return spots.act(act, id)
        case .spotReview(let id): return spots.review(id)
        case .gridEdit: return spots.editGrid()
        case .storeList(let frame): return StoreCalls(environment: environment, app: app).list(frame: frame)
        case .storeGet(let id): return StoreCalls(environment: environment, app: app).get(id)
        case .storePublish(let id): return StoreCalls(environment: environment, app: app).publish(id, account: account, caller: keyCaller)
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
        case .account(let call): return AccountCalls(account: account, caller: keyCaller).work(for: call, input: input)
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
        case .renderSpot, .render, .renderCard, .renderPanel, .renderStore, .helper, .glyphBook:
            return nil
        }
    }

    private static func startsScripts(_ call: CommandLineCall) -> Bool {
        switch call {
        case .check, .checkJSON, .spotRun, .sandbox: true
        default: false
        }
    }

    private var fence: Set<SpotUse>? {
        runs?.tokens.isCareful == true ? Set(SpotUse.allCases) : nil
    }

    private func fence(of caller: CallerTokens.Caller?) -> (caller: CallerTokens.Caller, mode: CarefulMode)? {
        guard let runs, runs.tokens.isCareful, let caller, !caller.uses.contains(.files) else { return nil }
        return (caller, CarefulMode(uses: caller.uses))
    }
}
