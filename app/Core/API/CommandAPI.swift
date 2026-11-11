import Foundation

/// The work of each `openspot <noun> <verb>` that Core does. The app gives it over its socket, and a process of its own
/// gives the same answer when the app does not run (S1, S2). It hands each call to the calls of its noun, and keeps the
/// stores of the Mac and the keyword files across calls, so that the app answers each later call from them.
public final class CommandAPI: @unchecked Sendable {
    public typealias Work = @Sendable () async -> CommandAnswer

    private let mac: any Mac
    /// Raises an event in the running app, or nil in a process with no app to reach.
    private let raise: (@Sendable (SpotEvent) async -> Void)?
    /// The rows of `openspot spot stats` in the running app, or nil in a process with no app to reach.
    private let stats: (@Sendable () -> String)?
    private let app: (any RunningApp)?
    private let calendar: CalendarCalls
    private let reminders: RemindersCalls
    private let keywords = GlyphKeywordCache()

    public init(mac: any Mac, raise: (@Sendable (SpotEvent) async -> Void)? = nil, stats: (@Sendable () -> String)? = nil, app: (any RunningApp)? = nil) {
        self.mac = mac
        self.raise = raise
        self.stats = stats
        self.app = app
        calendar = CalendarCalls(mac: mac)
        reminders = RemindersCalls(mac: mac)
    }

    /// The work that answers a call, or nil for a call that runs in a process of its own: one that draws, waits for the
    /// person, reaches the screen, a window or the clipboard, or runs a helper, a spot or a check of a folder. `input`
    /// reads stdin, and only a call that takes stdin reads it.
    public func work(for call: CommandLineCall, input: @escaping @Sendable () async -> String, environment: [String: String]) -> Work? {
        let isRead = environment["OPENSPOT_REASON"] != nil
        let spots = SpotCalls(environment: environment, app: app, stats: stats)
        let settings = SettingCalls(environment: environment, app: app)
        let keys = KeyCalls(environment: environment, app: app)
        let apps = AppCalls(mac: mac, environment: environment, app: app)
        switch call {
        case .help: return HelpCalls().list()
        case .guideOf(let noun): return HelpCalls().guide(of: noun)
        case .unknown(let words): return { CommandAnswer(errors: "openspot cannot do this: \(words)\n\n\(CommandLineCall.usage)", code: 2) }
        case .refused(let line): return { CommandAnswer(errors: "\(line)\n", code: 1) }
        case .guide: return GuideCalls(mac: mac).text()
        case .promptNew(let words): return PromptCalls(mac: mac, environment: environment).new(words)
        case .checkSheet: return CheckCalls(input: input).sheet()
        case .settingGet(let spot, let key): return settings.get(key, of: spot)
        case .settingSet(let spot, let key, let value): return settings.set(key, of: spot, to: value)
        case .settingList: return settings.list()
        case .settingChange(let spot, let key): return settings.change(key, of: spot)
        case .spotList(let core): return spots.list(core: core)
        case .spotTurn(let ids, let isOn): return spots.turn(ids, on: isOn)
        case .spotAdd(let source?): return spots.add(source)
        case .spotAdd(nil): return spots.restore()
        case .spotRemove(let id): return spots.remove(id)
        case .spotOpen(let id): return spots.open(id)
        case .spotReview(let id): return spots.review(id)
        case .spotNew(let name, let starter): return spots.new(name, from: starter)
        case .spotLog(let id): return spots.log(id)
        case .spotStats: return spots.statsText()
        case .appKeySet(let name, let key): return keys.set(app: name, to: key)
        case .keySet(let spot, let act, let key): return keys.set(act, of: spot, to: key)
        case .menuBar(let id, let isShown): return MenuBarCalls(environment: environment, app: app).show(id, isShown)
        case .appStatus: return apps.status()
        case .appLogin(let isOn): return apps.login(isOn)
        case .appLink(let isOn): return apps.link(isOn)
        case .appQuit: return apps.quit()
        case .updateCheck: return UpdateCalls(app: app).check()
        case .updateInstall: return UpdateCalls(app: app).install()
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
        case .check, .checkJSON, .spotRun, .spotShow, .renderSpot, .render, .renderCard, .sandbox, .colorPick, .folderPick,
             .clipboardCopy, .clipboardPaste, .translate, .translateLanguages, .windowFrame, .windowMove, .screenSources,
             .screenShot, .screenRecordStart, .screenRecordStop, .screenRecordStatus, .helper, .glyphBook:
            return nil
        }
    }
}
