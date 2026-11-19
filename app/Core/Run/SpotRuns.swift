import Foundation
import Observation

@MainActor
@Observable
public final class SpotRuns {
    public private(set) var sheets: [String: SpotRun] = [:]
    public internal(set) var isPanelOpen = false {
        didSet { if isPanelOpen != oldValue { usage.panel(shown: isPanelOpen) } }
    }
    public private(set) var openID: String?
    public private(set) var floating: Set<String> = []
    public var dragged = FileKinds() {
        didSet {
            guard dragged != oldValue else { return }
            let takers = dragged.paths.isEmpty ? [] : Set(sheets.filter { $0.value.spot.accepts(dragged) }.keys)
            if takers != dragTakers { dragTakers = takers }
        }
    }
    private var dragTakers: Set<String> = []
    @ObservationIgnored public var onReport: (String, SpotRun.Report) -> Void = { _, _ in }
    @ObservationIgnored public var partsArrival: (String, () -> Void) -> Void = { _, bring in bring() }
    @ObservationIgnored public let opening: SheetOpening
    public let showLimit: TimeInterval
    let inlineIdle: TimeInterval
    let frameWait: DispatchTimeInterval
    public nonisolated let usage: StatsLog
    @ObservationIgnored public var isCareful = false {
        didSet {
            callers.isCareful = isCareful
            guard isCareful != oldValue else { return }
            sheets.values.forEach { $0.restartScript() }
        }
    }
    public nonisolated let callers: SpotCallers
    @ObservationIgnored let clock: RunClock
    @ObservationIgnored let now: () -> Date
    @ObservationIgnored let stopPause: TimeInterval
    @ObservationIgnored let clipboardPause: Duration
    @ObservationIgnored var source: (any MacEvents)?
    @ObservationIgnored var clipboardWatch: Task<Void, Never>?
    @ObservationIgnored var clipboardSeen: Int?
    @ObservationIgnored var loadWatch: Task<Void, Never>?
    @ObservationIgnored let loadPause: Duration
    @ObservationIgnored var loadSeen: (sample: LoadSample, at: Date)?
    @ObservationIgnored private(set) var hasQuit = false
    @ObservationIgnored private let recent: (String) -> [String]
    @ObservationIgnored private let prepare: ([SpotItem], [String]) async -> Void
    @ObservationIgnored private var order: [String] = []

    @ObservationIgnored private var grid: Set<String> = []
    @ObservationIgnored private var menuBar: Set<String> = []
    public private(set) var menuBarMarks: [(id: String, mark: MenuBarMark)] = []
    @ObservationIgnored public private(set) var acts: [(id: String, call: ScriptCall)] = []
    public private(set) var runningSummary: String?
    public private(set) var actSpot: String?
    @ObservationIgnored var ticks: Task<Void, Never>?
    @ObservationIgnored var nextShow: Date?
    @ObservationIgnored var answerMatches = AnswerMatches()
    @ObservationIgnored private var lastSearch: SearchQuery?
    @ObservationIgnored private(set) var searchBuilds = 0

    func search(of text: String) -> SearchQuery {
        if let lastSearch, lastSearch.text == text.trimmingCharacters(in: .whitespaces) { return lastSearch }
        searchBuilds += 1
        let search = SearchQuery(text: text)
        lastSearch = search
        return search
    }
    @ObservationIgnored private(set) var processes: [ScriptProcess] = []
    @ObservationIgnored var loaded: [String: (stamp: [Int]?, script: InlineScript)] = [:]
    @ObservationIgnored private(set) var stamps: [String: [Int]] = [:]
    @ObservationIgnored var standIn: ((Spot) -> ScriptMode)?
    @ObservationIgnored public var api: CommandAPI?
    @ObservationIgnored private let log: CallLog?
    @ObservationIgnored public var onCall: ((CallLog.Record, ShowEvent?) -> Void)?
    @ObservationIgnored var frameWaits = 0
    @ObservationIgnored var answerWaits: [(DispatchTime) -> Void]?
    @ObservationIgnored private let swift: SwiftProgram
    @ObservationIgnored let environment: [String: String]
    @ObservationIgnored private(set) var settings: [String: [String: String]] = [:]
    @ObservationIgnored public var secrets: SecretStore?

    public func take(settings values: [SpotSetting]) {
        var next: [String: [String: String]] = [:]
        for value in values { next[value.spot, default: [:]][value.key] = value.value }
        settings = next
    }

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        showLimit: TimeInterval = 10,
        opening: SheetOpening = SheetOpening(),
        clock: RunClock = RunClock(),
        stopPause: TimeInterval = 2,
        clipboardPause: Duration = .milliseconds(500),
        loadPause: Duration = .seconds(5),
        recent: @escaping (String) -> [String] = { _ in [] },
        prepare: @escaping ([SpotItem], [String]) async -> Void = { _, _ in },
        inlineIdle: TimeInterval = 30,
        frameWait: DispatchTimeInterval = .milliseconds(2),
        log: CallLog? = nil,
        stats: URL? = nil,
        swift: SwiftProgram = SwiftProgram(),
        callers: SpotCallers = SpotCallers()
    ) {
        self.environment = environment
        self.callers = callers
        self.log = log
        self.swift = swift
        usage = StatsLog(folder: stats, at: clock.now(), now: clock.now)
        self.inlineIdle = inlineIdle
        self.frameWait = frameWait
        self.showLimit = showLimit
        self.opening = opening
        self.clock = clock
        now = clock.now
        self.stopPause = stopPause
        self.clipboardPause = clipboardPause
        self.loadPause = loadPause
        self.recent = recent
        self.prepare = prepare
    }

    nonisolated deinit {}

    public func take(_ scan: ScanResult, menuBar: Set<String> = [], stamps: [String: [Int]] = [:]) {
        let scripts = scan.scripts
        self.stamps = stamps
        for (id, kept) in loaded where kept.stamp != stamps[id] { dropScript(of: id) }
        self.menuBar = menuBar
        order = scripts.map(\.id)
        let owners = Dictionary(scan.spots.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for (id, sheet) in sheets where !order.contains(id) {
            if let settings = SpotSettings.owner(of: id).flatMap({ owners[$0] })?.settingsSpot {
                sheet.update(settings)
                continue
            }
            if let owner = OwnedSheet.owner(of: id), owner.sheet == .edit, owners[owner.spot] != nil, editor != nil { continue }
            sheets[id] = nil
            if sheet.isOpen { onReport(id, .closed) }
            if floating.remove(id) != nil { onReport(id, .landed) }
            sheet.close()
            sheet.stopShows()
        }
        scripts.forEach { sheet(for: $0).scanned(stamps[$0.id]) }
        showMarks()
        showActs()
        swift.prune(keeping: scripts.map(\.url), with: Dictionary(scripts.map { ($0.url, $0.sources) }) { first, _ in first })
        usage.take(views: scripts)
        usage.take(versions: stamps.mapValues(SpotLoad.version(of:)))
        updateClock()
        showOfferedItems()
    }

    public func sheet(for spot: Spot) -> SpotRun {
        if let sheet = sheets[spot.id] {
            sheet.update(spot)
            return sheet
        }
        let id = spot.id
        let sheet = SpotRun(spot: spot, runs: self, recent: recent(id), prepare: prepare)
        sheet.onReport = { [weak self] in self?.onReport(id, $0) }
        sheet.partsArrival = { [weak self] bring in
            guard let self else { return bring() }
            partsArrival(id, bring)
        }
        sheets[id] = sheet
        return sheet
    }

    @discardableResult
    public func settingsSheet(of spot: Spot) -> SpotRun? {
        spot.settingsSpot.map(sheet(for:))
    }

    public var editsSpots: Bool {
        editor != nil
    }

    private var editor: Spot? {
        sheets.values.lazy.map(\.spot).first { $0.editsSpots && $0.isBuiltIn }
    }

    @discardableResult
    public func editSheet(of spot: Spot, isOwn: Bool) -> SpotRun? {
        editor?.editSheet(of: spot, isOwn: isOwn).map(sheet(for:))
    }

    func willOpen(_ sheet: SpotRun) {
        let id = sheet.spot.id
        if let open = openID, open != id { sheets[open]?.close() }
        openID = id
    }

    func didClose(_ sheet: SpotRun) {
        if openID == sheet.spot.id { openID = nil }
    }

    public func float(_ id: String) {
        guard let sheet = sheets[id], floating.insert(id).inserted else { return }
        sheet.floated()
    }

    public func land(_ id: String) {
        guard floating.remove(id) != nil else { return }
        sheets[id]?.leftPlace()
        updateClock()
    }

    public func closeOpen() {
        openID.flatMap { sheets[$0] }?.close()
    }

    public var firstLaunchSheet: String? {
        sheets.values.lazy.map(\.spot).first { $0.starts == .firstLaunch && $0.isBuiltIn }?.id
    }

    public var isShowing: Bool {
        sheets.values.contains(where: \.isShowing)
    }

    public func panelClosed() {
        isPanelOpen = false
        sheets.values.forEach { $0.leftPlace() }
        updateClock()
    }

    public func quit() {
        hasQuit = true
        ticks?.cancel()
        ticks = nil
        clipboardWatch?.cancel()
        clipboardWatch = nil
        loadWatch?.cancel()
        loadWatch = nil
        opening.end()
        let live = processes.filter(\.needsFinish)
        sheets.values.forEach { $0.prepareToQuit() }
        live.forEach { $0.leave() }
        let deadline = Date().addingTimeInterval(stopPause)
        live.forEach { $0.finish(by: deadline) }
        loaded.keys.forEach { dropScript(of: $0) }
        usage.flush()
    }

    func showMarks(of id: String? = nil) {
        if let id, !menuBar.contains(id) { return }
        let marks: [(id: String, mark: MenuBarMark)] = order.compactMap { id in
            guard let sheet = sheets[id], isInMenuBar(sheet.spot) else { return nil }
            guard sheet.reading.hasBar else { return (id, MenuBarMark(icon: sheet.spot.symbol, name: sheet.spot.name)) }
            return MenuBarMark(reading: sheet.reading).map { (id, $0) }
        }
        guard !marks.elementsEqual(menuBarMarks, by: { $0.id == $1.id && $0.mark == $1.mark }) else { return }
        menuBarMarks = marks
    }

    private func isInMenuBar(_ spot: Spot) -> Bool {
        menuBar.contains(spot.id) && spot.canShowInMenuBar
    }

    func showActs() {
        let next = order.flatMap { id in (sheets[id]?.acts ?? []).map { (id: id, call: $0) } }.sorted { $0.call.started < $1.call.started }
        guard !next.elementsEqual(acts, by: { $0.id == $1.id && $0.call === $1.call }) else { return }
        acts = next
        let name = next.first.map { sheets[$0.id]?.spot.name ?? $0.id }
        let summary = name.map { next.count > 1 ? "\(next.count) running. \($0) is the oldest" : "\($0) is running" }
        if summary != runningSummary { runningSummary = summary }
        if next.first?.id != actSpot { actSpot = next.first?.id }
    }

    public func takesDrag(_ id: String) -> Bool {
        dragTakers.contains(id)
    }

    public func answer(of spot: Spot, _ action: SpotAction, input: String? = nil, limit: TimeInterval? = nil, variables: [String: String] = [:]) async throws -> String {
        try await mode(of: spot).answer(of: spot, action, input: input, limit: limit, variables: variables, in: self)
    }

    func wants(_ spot: Spot) -> Bool {
        if isInMenuBar(spot) || spot.mode == .stay && spot.showsAtLaunch { return true }
        guard isPanelOpen else { return false }
        return spot.mode.stays && spot.answers != nil || spot.on?.has(.panel) == true || grid.contains(spot.id)
    }

    public func take(grid next: Set<String>) {
        guard next != grid else { return }
        grid = next
        guard isPanelOpen else { return }
        sheets.values.forEach { $0.settleScript() }
        updateClock()
    }

    func intake(_ frame: String, of id: String?) async -> SpotOutput {
        let shown = id.flatMap { sheets[$0] }.flatMap { $0.shownFrame == frame ? $0.lastAnswer : nil }
        let lines = if let shown { shown } else { await SpotOutput.reading(frame) }
        guard let id, opening.moving == id else { return lines }
        sheets[id]?.hear(lines)
        await opening.waitForMotion(of: id)
        sheets[id]?.hear(nil)
        return lines
    }

    private static func isQuiet(_ event: ShowEvent?, _ end: ScriptCall.End) -> Bool {
        guard event?.isFrequent == true else { return false }
        if case .failed = end { return false }
        return true
    }

    func add(_ frame: String, to frames: inout [String]) {
        if let log { log.add(frame, to: &frames) } else if onCall != nil { frames.append(frame) }
    }

    func record(_ spot: Spot, _ action: SpotAction, input: String?, frames: [String], errors: String, end: ScriptCall.End, event: ShowEvent?, started: Date, begin: Date) {
        guard !spot.reachesAccountKey else { return }
        let record = CallLog.Record(
            spot: spot.id,
            arguments: action.arguments,
            input: input,
            frames: frames,
            errors: errors,
            end: CallLog.End(end),
            started: started,
            seconds: Date().timeIntervalSince(begin)
        )
        onCall?(record, event)
        guard let log, !Self.isQuiet(event, end) else { return }
        log.write(record)
    }

    func stay(_ spot: Spot, limit: TimeInterval?) -> (ScriptProcess, AsyncThrowingStream<String, Error>, SpotCaller) {
        let caller = callers.issue(for: spot)
        let script = ScriptProcess(spot: spot, program: swift.runnable(for: spot), swift: swift, sending: nil, limit: limit, stopPause: stopPause, careful: isCareful ? spot.uses : nil, base: environment)
        track(script, of: spot.id, caller: caller)
        let frames = script.start()
        keep(script)
        return (script, frames, caller)
    }

    func process(of spot: Spot, _ message: Message, limit: TimeInterval?, reason: String?, variables given: [String: String], call: OpenCall?) -> ScriptMode.Frames {
        let caller = callers.issue(for: spot, reason: reason, keepsFix: true)
        caller.call = call
        let process = ScriptProcess(spot: spot, program: swift.runnable(for: spot), swift: swift, sending: message, limit: limit, stopPause: stopPause, variables: variables(of: spot, given: given), careful: isCareful ? spot.uses : nil, base: environment)
        track(process, of: spot.id, caller: caller)
        process.fix = { caller.takeFix() }
        let stream = process.start()
        keep(process)
        return (stream, { process.stop() }, process)
    }

    func variables(of spot: Spot, given: [String: String]) -> [String: String] {
        given.merging(editing(spot)) { given, _ in given }.filter { spot.isBuiltIn || !ScriptProcess.appVariables.contains($0.key) }
    }

    private func editing(_ spot: Spot) -> [String: String] {
        guard let owner = OwnedSheet.owner(of: spot.id), owner.sheet == .edit else { return [:] }
        var variables = ["OPENSPOT_EDIT": owner.spot]
        variables["OPENSPOT_EDIT_FILE"] = spot.editedFile?.path
        variables["OPENSPOT_EDIT_FAILURE"] = sheets[owner.spot]?.failure
        return variables
    }

    func answered(by work: @escaping @Sendable () async throws -> String) -> (stream: AsyncThrowingStream<String, Error>, halt: () -> Void) {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: String.self)
        let task = Task {
            do {
                let text = try await work()
                if !text.isEmpty { continuation.yield(text) }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        return (stream, {
            task.cancel()
            continuation.finish()
        })
    }

    func used(_ call: SpotUseCall, by caller: Spot) {
        guard usage.used(call, by: caller, at: now()) else { return }
        onReport(caller.id, .toast("\(caller.name) \(call.words) without `\(call.use.rawValue)` in the `uses` of its spot.toml. Add it to stop this note."))
    }

    private func track(_ process: ScriptProcess, of spot: String, caller: SpotCaller) {
        usage.track(process, of: spot)
        callers.attach(process, to: caller)
    }

    private func keep(_ process: ScriptProcess) {
        dropFinished()
        processes.append(process)
    }

    func isBuilding(_ spot: Spot) -> Bool {
        processes.contains { $0.isBuilding(spot.url.path) }
    }

    func dropFinished() {
        processes.removeAll { !$0.needsFinish }
    }
}
