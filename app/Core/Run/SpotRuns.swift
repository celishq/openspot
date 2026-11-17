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
    public let readLimit: TimeInterval
    let inlineIdle: TimeInterval
    let frameWait: DispatchTimeInterval
    public nonisolated let usage: StatsLog
    @ObservationIgnored public var isCareful = false {
        didSet {
            tokens.isCareful = isCareful
            guard isCareful != oldValue else { return }
            sheets.values.forEach { $0.restartScript() }
        }
    }
    public nonisolated let tokens: CallerTokens
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

    @ObservationIgnored private(set) var placed: Set<String> = []
    @ObservationIgnored private var menuBar: Set<String> = []
    public private(set) var menuBarMarks: [(id: String, mark: MenuBarMark)] = []
    @ObservationIgnored public private(set) var work: [(id: String, call: ScriptCall)] = []
    public private(set) var runningSummary: String?
    public private(set) var workSpot: String?
    @ObservationIgnored var ticks: Task<Void, Never>?
    @ObservationIgnored var nextRead: Date?
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
    @ObservationIgnored var standIn: ((Spot) -> ScriptLink)?
    @ObservationIgnored public var api: CommandAPI?
    @ObservationIgnored private let log: CallLog?
    @ObservationIgnored public var onCall: ((CallLog.Record, ReadReason?) -> Void)?
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
        readLimit: TimeInterval = 10,
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
        tokens: CallerTokens = CallerTokens()
    ) {
        self.environment = environment
        self.tokens = tokens
        self.log = log
        self.swift = swift
        usage = StatsLog(folder: stats, at: clock.now(), now: clock.now)
        self.inlineIdle = inlineIdle
        self.frameWait = frameWait
        self.readLimit = readLimit
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
        placed = Set(scan.spots.flatMap(\.places))
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
            sheet.stopReads()
        }
        scripts.forEach { sheet(for: $0).scanned(stamps[$0.id]) }
        showMarks()
        showWork()
        swift.prune(keeping: scripts.map(\.url), with: Dictionary(scripts.map { ($0.url, $0.sources) }) { first, _ in first })
        usage.take(views: scripts)
        usage.take(versions: stamps.mapValues(SpotLoad.version(of:)))
        updateClock()
        readOfferedRows()
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

    public var isReading: Bool {
        sheets.values.contains(where: \.isReading)
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
            guard sheet.spot.showsValueInMenuBar else { return (id, MenuBarMark(icon: sheet.spot.symbol, name: sheet.spot.name)) }
            return MenuBarMark(reading: sheet.reading).map { (id, $0) }
        }
        guard !marks.elementsEqual(menuBarMarks, by: { $0.id == $1.id && $0.mark == $1.mark }) else { return }
        menuBarMarks = marks
    }

    private func isInMenuBar(_ spot: Spot) -> Bool {
        menuBar.contains(spot.id) && spot.canShowInMenuBar
    }

    func showWork() {
        let next = order.flatMap { id in (sheets[id]?.work ?? []).map { (id: id, call: $0) } }.sorted { $0.call.started < $1.call.started }
        guard !next.elementsEqual(work, by: { $0.id == $1.id && $0.call === $1.call }) else { return }
        work = next
        let name = next.first.map { sheets[$0.id]?.spot.name ?? $0.id }
        let summary = name.map { next.count > 1 ? "\(next.count) running. \($0) is the oldest" : "\($0) is running" }
        if summary != runningSummary { runningSummary = summary }
        if next.first?.id != workSpot { workSpot = next.first?.id }
    }

    public func takesDrag(_ id: String) -> Bool {
        dragTakers.contains(id)
    }

    public func answer(of spot: Spot, _ action: SpotAction, input: String? = nil, limit: TimeInterval? = nil, variables: [String: String] = [:]) async throws -> String {
        if ScriptKind(of: spot) == .stay, action == .read {
            let (script, frames, token) = stay(spot, limit: limit)
            tokens.setReason(ReadReason.panel.rawValue, of: token)
            defer { script.end() }
            script.send(.read, variables: ReadReason.panel.variables.merging(variables) { _, new in new }, id: 1)
            for try await frame in frames {
                let head = FrameHead(text: frame)
                if !head.isMark || head.end == "1" { return frame }
            }
            return ""
        }
        let (stream, halt, _) = frames(of: spot, action, input: input, limit: limit, variables: variables)
        defer { if sheets[spot.id] == nil { dropScript(of: spot.id) } }
        if action == .read {
            defer { halt() }
            for try await frame in stream { return frame }
            return ""
        }
        var text = ""
        for try await frame in stream { text += frame }
        return text
    }

    func wants(_ spot: Spot) -> Bool {
        if isInMenuBar(spot) || spot.mode == .always { return true }
        if isPanelOpen, spot.mode.stays, spot.answers != nil { return true }
        guard let read = spot.read else { return false }
        return isPanelOpen && (read.has(.panel) || placed.contains(spot.id))
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

    private static func isQuiet(_ reason: ReadReason?, _ end: ScriptCall.End) -> Bool {
        guard reason?.isFrequent == true else { return false }
        if case .failed = end { return false }
        return true
    }

    func add(_ frame: String, to frames: inout [String]) {
        if let log { log.add(frame, to: &frames) } else if onCall != nil { frames.append(frame) }
    }

    func record(_ spot: Spot, _ action: SpotAction, input: String?, frames: [String], errors: String, end: ScriptCall.End, reason: ReadReason?, started: Date, begin: Date) {
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
        onCall?(record, reason)
        guard let log, !Self.isQuiet(reason, end) else { return }
        log.write(record)
    }

    func stay(_ spot: Spot, limit: TimeInterval?) -> (ScriptProcess, AsyncThrowingStream<String, Error>, String) {
        let token = tokens.issue(for: spot)
        let script = ScriptProcess(url: swift.runnable(for: spot), name: spot.url.path, mode: .stays, limit: limit, stopPause: stopPause, dataName: spot.dataName, variables: ["OPENSPOT_ID": spot.id, CallerTokens.variable: token], careful: isCareful ? spot.uses : nil, base: environment, build: swift.build(of: spot))
        track(script, of: spot.id, token: token)
        let frames = script.start()
        keep(script)
        return (script, frames, token)
    }

    func frames(of spot: Spot, _ action: SpotAction, input: String?, limit: TimeInterval?, variables given: [String: String] = [:]) -> (stream: AsyncThrowingStream<String, Error>, halt: () -> Void, process: ScriptProcess?) {
        let variables = given.merging(editing(spot)) { given, _ in given }
        switch ScriptKind(of: spot) {
        case .settings(let settings):
            let (stream, halt) = answered { try settings.answer(action.arguments) }
            return (stream, halt, nil)
        case .host(let sheet):
            let (stream, halt) = answered { [environment] in try await sheet.answer(action.arguments, input: input, variables: variables, base: environment) }
            return (stream, halt, nil)
        case .inline:
            let call = InlineCall(arguments: action.arguments, variables: variables, input: input, limit: limit)
            script(of: spot).send(call)
            let (stream, halt) = answered {
                switch await call.outcome(limit: limit) {
                case .frame(let text): return text
                case .failed(let error): throw error
                case .dropped: return ""
                }
            }
            return (stream, {
                call.stop()
                halt()
            }, nil)
        case .stay, .once:
            let sent = action.sent(input: input)
            let token = tokens.issue(for: spot, reason: variables[ReadReason.variable], keepsFix: true)
            let process = ScriptProcess(url: swift.runnable(for: spot), name: spot.url.path, arguments: sent.arguments, mode: .once(input: sent.input), limit: limit, stopPause: stopPause, dataName: spot.dataName, variables: variables.merging(["OPENSPOT_ID": spot.id]) { given, _ in given }.merging([CallerTokens.variable: token]) { _, own in own }, careful: isCareful ? spot.uses : nil, base: environment, build: swift.build(of: spot))
            track(process, of: spot.id, token: token)
            process.fix = { [tokens] in tokens.fix(of: token) }
            let stream = process.start()
            keep(process)
            return (stream, { process.stop() }, process)
        }
    }

    private func editing(_ spot: Spot) -> [String: String] {
        guard let owner = OwnedSheet.owner(of: spot.id), owner.sheet == .edit else { return [:] }
        var variables = ["OPENSPOT_EDIT": owner.spot]
        variables["OPENSPOT_EDIT_FILE"] = spot.editedFile?.path
        variables["OPENSPOT_EDIT_FAILURE"] = sheets[owner.spot]?.failure
        return variables
    }

    private func answered(by work: @escaping @Sendable () async throws -> String) -> (stream: AsyncThrowingStream<String, Error>, halt: () -> Void) {
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

    func used(_ call: SpotUseCall, by caller: CallerTokens.Caller) {
        guard usage.used(call, by: caller, at: now()) else { return }
        onReport(caller.id, .toast("\(caller.name) \(call.words) without `uses=\(call.use.rawValue)` in its header. Add it to stop this note."))
    }

    private func track(_ process: ScriptProcess, of spot: String, token: String) {
        usage.track(process, of: spot)
        process.onStart { [tokens] group in tokens.enter(group, token: token) }
        process.onExit { [tokens] _ in tokens.release(token) }
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
