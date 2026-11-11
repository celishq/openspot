import Foundation

/// The work of each `openspot <noun> <verb>` that Core does. The app gives it over its socket, and a process of its own
/// gives the same answer when the app does not run (S1, S2). It makes each store of the host and the keyword files once,
/// so that the app answers each later call from them.
public final class CommandAPI: @unchecked Sendable {
    public typealias Work = @Sendable () async -> CommandAnswer

    private let host: any CommandHost
    /// Raises an event in the running app, or nil in a process with no app to reach.
    private let raise: (@Sendable (SpotEvent) async -> Void)?
    /// The rows of `openspot spot stats` in the running app, or nil in a process with no app to reach.
    private let stats: (@Sendable () -> String)?
    private let app: (any RunningApp)?
    private let lock = NSLock()
    /// The stores kept warm across calls, each one only once the person gave it leave.
    private var eventStore: (any EventStore)?
    private var reminderStore: (any ReminderStore)?
    private var glyphKeywords: GlyphKeywords?

    public init(host: any CommandHost, raise: (@Sendable (SpotEvent) async -> Void)? = nil, stats: (@Sendable () -> String)? = nil, app: (any RunningApp)? = nil) {
        self.host = host
        self.raise = raise
        self.stats = stats
        self.app = app
    }

    /// The work that answers a call, or nil for a call that runs in a process of its own: one that draws, waits for the
    /// person, reaches the screen, a window or the clipboard, or runs a helper, a spot or a check of a folder. `input`
    /// reads stdin, and only a call that takes stdin reads it.
    public func work(for call: CommandLineCall, input: @escaping @Sendable () async -> String, environment: [String: String]) -> Work? {
        let isRead = environment["OPENSPOT_REASON"] != nil
        switch call {
        case .help:
            return { CommandAnswer(output: CommandLineCall.usage) }
        case .unknown(let words):
            return { CommandAnswer(errors: "openspot cannot do this: \(words)\n\n\(CommandLineCall.usage)", code: 2) }
        case .refused(let line):
            return { CommandAnswer(errors: "\(line)\n", code: 1) }
        case .settingGet(let spot, let key):
            return Self.answer { ConfigFile.standard(environment: environment).read().setting(key, of: spot).map { $0 + "\n" } ?? "" }
        case .settingSet(let spot, let key, let value):
            return Self.answer {
                try ConfigFile.standard(environment: environment).set(setting: key, of: spot, to: value)
                return ""
            }
        case .settingList:
            return Self.answer { try SpotList(folder: PluginFolder.standard(environment: environment), config: ConfigFile.standard(environment: environment).read()).values() }
        case .spotList(let core):
            return Self.answer {
                let list = SpotList(folder: PluginFolder.standard(environment: environment), config: ConfigFile.standard(environment: environment).read())
                return try core ? list.core() : list.loaded()
            }
        case .spotTurn(let ids, let isOn):
            return Self.answer {
                try PluginFolder.standard(environment: environment).turn(ids, on: isOn, in: ConfigFile.standard(environment: environment))
                await self.app?.configChanged()
                return ""
            }
        case .appKeySet(let name, let key):
            return Self.answer {
                guard let shortcut = Shortcut(text: key) else { throw PluginError.failed(1, "Openspot cannot use `\(key)`. Hold cmd, ctrl or option with a letter, a digit, an arrow, space, return or tab.") }
                try ConfigFile.standard(environment: environment).set(name, to: shortcut.text)
                await self.app?.configChanged()
                return ""
            }
        case .keySet(let spot, let act, let key):
            return Self.answer {
                let trigger = try key.map { key in
                    guard let trigger = Trigger(text: key) else { throw PluginError.failed(1, "Openspot cannot use `\(key)`. Hold cmd, ctrl or option with a letter, a digit, an arrow, space, return or tab, or use shake.") }
                    return trigger
                }
                try ConfigFile.standard(environment: environment).assign(trigger, to: spot, act: act)
                await self.app?.configChanged()
                return ""
            }
        case .menuBar(let id, let isShown):
            return Self.answer {
                try ConfigFile.standard(environment: environment).showInMenuBar(id, isShown)
                await self.app?.configChanged()
                return ""
            }
        case .appStatus:
            return Self.answer {
                let config = ConfigFile.standard(environment: environment).read()
                let running = await self.app?.status()
                return try AppStatus(
                    version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
                    panelKey: (config.panelKey ?? .standard).text,
                    fixKey: (config.fixKey ?? .fix).text,
                    login: self.host.login?.isOn(),
                    link: self.host.link?.isOn,
                    update: running?.update,
                    calls: running?.calls,
                    firstLaunch: running?.isFirstLaunch
                ).json()
            }
        case .appLogin(let isOn):
            return Self.answer {
                guard let login = self.host.login else { throw PluginError.failed(1, "This copy of Openspot cannot open at login. Move it to Applications, then try again.") }
                try login.set(isOn)
                return ""
            }
        case .appLink(let isOn):
            return Self.answer {
                guard let link = self.host.link else { throw PluginError.failed(1, "This copy of Openspot cannot put openspot in Terminal.") }
                try link.set(isOn)
                return ""
            }
        case .appQuit:
            guard let app else { return Self.notRunning }
            return {
                await app.quit()
                return CommandAnswer()
            }
        case .updateCheck:
            guard let app else { return Self.notRunning }
            return Self.answer {
                guard await app.checkUpdate() else { throw PluginError.failed(1, "This copy of Openspot does not update itself.") }
                return ""
            }
        case .updateInstall:
            guard let app else { return Self.notRunning }
            return Self.answer {
                guard await app.installUpdate() else { throw PluginError.failed(1, "No update is ready. Run `openspot update check` first.") }
                return ""
            }
        case .guide:
            return Self.answer {
                guard let guide = Bundle.main.url(forResource: "GUIDE", withExtension: "md") else { throw PluginError.fault("This copy of Openspot has no guide. Install Openspot again.") }
                return try String(contentsOf: guide, encoding: .utf8)
            }
        case .guideOf(let noun):
            return Self.answer {
                guard let folder = Bundle.main.url(forResource: "Help", withExtension: nil) else { throw PluginError.fault("This copy of Openspot has no guides. Install Openspot again.") }
                return try CommandGuide(folder: folder).text(of: noun)
            }
        case .spotNew(let name, let starter):
            return Self.answer {
                let file = try starter.write(name: name, in: PluginFolder.standard(environment: environment).url)
                return "Wrote \(file.path). Its ID is \(file.deletingPathExtension().lastPathComponent).\n"
            }
        case .spotLog(let id):
            return Self.answer {
                let text = SpotFiles(environment: environment, home: FileManager.default.homeDirectoryForCurrentUser, defaults: .standard).log.text(of: id)
                return text.isEmpty ? "Openspot has made no call to \(id) yet. Use it in the panel, then run this again.\n" : text
            }
        case .spotStats:
            guard let stats else {
                return { CommandAnswer(errors: "Openspot is not running, so it has counted no calls. Open Openspot, then run this again.\n", code: 1) }
            }
            return { CommandAnswer(output: stats()) }
        case .checkSheet:
            return {
                let faults = PluginOutput(text: await input()).sheetFaults
                let text = faults.map { $0 + "\n" }.joined() + (faults.isEmpty ? "No faults.\n" : "\(faults.count) faults.\n")
                return CommandAnswer(output: text, code: faults.isEmpty ? 0 : 1)
            }
        case .eventEmit(let name, let value):
            guard let raise else {
                return { CommandAnswer(errors: "Openspot is not running, so no spot hears `\(name)`. Open Openspot, then run this again.\n", code: 1) }
            }
            return {
                await raise(.named(name, value: value))
                return CommandAnswer()
            }
        case .calcSolve(let words):
            return Self.answer { CalcAnswer(text: words, rates: CalcRateCache.ask)?.text ?? "" }
        case .emoji(let tone):
            return Self.answer { try EmojiCatalog(keywords: self.keywords()).rows(tone: tone) }
        case .symbols:
            return Self.answer { try SymbolCatalog(keywords: self.keywords()).rows() }
        case .calendarEvents(let days, let hidden):
            return Self.answer { try await self.events(isRead).events(days: days, hiding: hidden) }
        case .calendarCalendars:
            return Self.answer { try await self.events(isRead).calendars() }
        case .calendarAdd(let words, let isDry):
            return Self.answer { try await self.events(isRead).add(words, isDry: isDry) }
        case .calendarShow(let id):
            return Self.answer {
                try self.host.showCalendar(at: try await self.events(isRead).day(of: id))
                return ""
            }
        case .remindersDue(let days, let hidden):
            return Self.answer { try await self.reminders(isRead).due(days: days, hiding: hidden) }
        case .remindersLists:
            return Self.answer { try await self.reminders(isRead).lists() }
        case .remindersAdd(let words, let isDry):
            return Self.answer { try await self.reminders(isRead).add(words, isDry: isDry) }
        case .remindersDone(let id, let isDone):
            return Self.answer { try await self.reminders(isRead).done(id, isDone) }
        case .remindersShow(let id):
            return Self.answer {
                let link = try await self.reminders(isRead).link(of: id)
                guard self.host.open(link) else { throw PluginError.failed(1, "Openspot cannot open Reminders, so it cannot show \(id).") }
                return ""
            }
        case .check, .checkJSON, .spotRun, .spotShow, .renderSpot, .render, .renderCard, .sandbox, .colorPick, .folderPick,
             .clipboardCopy, .clipboardPaste, .translate, .translateLanguages, .windowFrame, .windowMove, .screenSources,
             .screenShot, .screenRecordStart, .screenRecordStop, .screenRecordStatus, .helper, .glyphBook:
            return nil
        }
    }

    private func events(_ isRead: Bool) -> Events {
        let store = lock.withLock {
            let store = eventStore ?? host.eventStore()
            eventStore = store.access() == .allowed ? store : nil
            return store
        }
        return Events(store: store, isRead: isRead)
    }

    private func reminders(_ isRead: Bool) -> Reminders {
        let store = lock.withLock {
            let store = reminderStore ?? host.reminderStore()
            reminderStore = store.access() == .allowed ? store : nil
            return store
        }
        return Reminders(store: store, isRead: isRead)
    }

    private func keywords() -> GlyphKeywords {
        lock.withLock {
            let keywords = glyphKeywords ?? GlyphKeywords()
            glyphKeywords = keywords
            return keywords
        }
    }

    /// The work of a call that only the running app can answer, when no app runs.
    private static let notRunning: Work = {
        CommandAnswer(errors: "Openspot is not running. Open Openspot, then run this again.\n", code: 1)
    }

    /// The work that prints what the text work returns, and fails as `CommandAnswer(failure:)` says.
    private static func answer(_ work: @escaping @Sendable () async throws -> String) -> Work {
        {
            do { return CommandAnswer(output: try await work()) } catch { return CommandAnswer(failure: error) }
        }
    }
}
