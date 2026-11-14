import Foundation
import Observation

@MainActor
@Observable
public final class SpotRuns {
    public private(set) var sheets: [String: SpotRun] = [:]
    public internal(set) var isPanelOpen = false
    public private(set) var openID: String?
    public private(set) var floating: Set<String> = []
    public var draggedPaths: [String] = [] {
        didSet {
            guard draggedPaths != oldValue else { return }
            let takers = draggedPaths.isEmpty ? [] : Set(sheets.filter { $0.value.spot.accepts(draggedPaths) }.keys)
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
    public nonisolated let usage: SpotUsage
    @ObservationIgnored public var isCareful = false {
        didSet {
            tokens.isCareful = isCareful
            guard isCareful != oldValue else { return }
            sheets.values.forEach { $0.restartScript() }
        }
    }
    public nonisolated let tokens: CallerTokens
    @ObservationIgnored let now: () -> Date
    @ObservationIgnored private let stopPause: TimeInterval
    @ObservationIgnored let tickPause: Duration
    @ObservationIgnored let clipboardPause: Duration
    @ObservationIgnored var source: (any Mac)?
    @ObservationIgnored var clipboardWatch: Task<Void, Never>?
    @ObservationIgnored var clipboardSeen: Int?
    @ObservationIgnored private(set) var hasQuit = false
    @ObservationIgnored private let recent: (String) -> [String]
    @ObservationIgnored private let prepare: ([SpotItem], [String]) async -> Void
    private var order: [String] = []

    @ObservationIgnored private(set) var placed: Set<String> = []
    private var menuBar: Set<String> = []
    @ObservationIgnored var lastClockRead: [String: Date] = [:]
    @ObservationIgnored var clock: Task<Void, Never>?
    @ObservationIgnored var nextRead: TimeInterval?
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
    @ObservationIgnored var hookScripts: [String: (spot: Spot, script: InlineScript)] = [:]
    @ObservationIgnored public var api: CommandAPI?
    @ObservationIgnored private let log: CallLog?
    @ObservationIgnored public var onCall: ((CallLog.Record, ReadReason?) -> Void)?
    @ObservationIgnored var frameWaits = 0
    @ObservationIgnored var answerWaits: [(DispatchTime) -> Void]?
    @ObservationIgnored private let swift: SwiftProgram

    public init(
        readLimit: TimeInterval = 10,
        opening: SheetOpening = SheetOpening(),
        now: @escaping () -> Date = { Date() },
        stopPause: TimeInterval = 2,
        tickPause: Duration = .seconds(1),
        clipboardPause: Duration = .milliseconds(500),
        recent: @escaping (String) -> [String] = { _ in [] },
        prepare: @escaping ([SpotItem], [String]) async -> Void = { _, _ in },
        inlineIdle: TimeInterval = 30,
        frameWait: DispatchTimeInterval = .milliseconds(2),
        log: CallLog? = nil,
        stats: URL? = nil,
        swift: SwiftProgram = SwiftProgram(),
        tokens: CallerTokens = CallerTokens()
    ) {
        self.tokens = tokens
        self.log = log
        self.swift = swift
        usage = SpotUsage(folder: stats, at: now(), now: now)
        self.inlineIdle = inlineIdle
        self.frameWait = frameWait
        self.readLimit = readLimit
        self.opening = opening
        self.now = now
        self.stopPause = stopPause
        self.tickPause = tickPause
        self.clipboardPause = clipboardPause
        self.recent = recent
        self.prepare = prepare
    }

    nonisolated deinit {}

    public func take(_ scan: ScanResult, menuBar: Set<String> = []) {
        let scripts = scan.scripts
        placed = Set(scan.spots.flatMap(\.places))
        self.menuBar = menuBar
        order = scripts.map(\.id)
        for (id, sheet) in sheets where !order.contains(id) {
            sheets[id] = nil
            if sheet.isOpen { onReport(id, .closed) }
            if floating.remove(id) != nil { onReport(id, .landed) }
            sheet.close()
            sheet.stopReads()
        }
        scripts.forEach { sheet(for: $0).scanned() }
        swift.prune(keeping: scripts.map(\.url))
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
        clock?.cancel()
        clock = nil
        clipboardWatch?.cancel()
        clipboardWatch = nil
        opening.end()
        let live = processes.filter(\.needsFinish)
        sheets.values.forEach { $0.prepareToQuit() }
        live.forEach { $0.leave() }
        let deadline = Date().addingTimeInterval(stopPause)
        live.forEach { $0.finish(by: deadline) }
        usage.flush()
    }

    public var menuBarMarks: [(id: String, mark: MenuBarMark)] {
        order.compactMap { id in
            guard let sheet = sheets[id], isInMenuBar(sheet.spot), let mark = MenuBarMark(reading: sheet.reading) else { return nil }
            return (id, mark)
        }
    }

    private func isInMenuBar(_ spot: Spot) -> Bool {
        menuBar.contains(spot.id) && spot.canShowInMenuBar
    }

    public var work: [(id: String, call: ScriptCall)] {
        order.flatMap { id in (sheets[id]?.work ?? []).map { (id: id, call: $0) } }.sorted { $0.call.started < $1.call.started }
    }

    public var runningSummary: String? {
        let work = work
        guard let oldest = work.first else { return nil }
        let name = sheets[oldest.id]?.spot.name ?? oldest.id
        return work.count > 1 ? "\(work.count) running. \(name) is the oldest" : "\(name) is running"
    }

    public var workSpot: String? {
        work.first?.id
    }

    public func takesDrag(_ id: String) -> Bool {
        dragTakers.contains(id)
    }

    public func answer(of spot: Spot, _ action: SpotAction, input: String? = nil, limit: TimeInterval? = nil, variables: [String: String] = [:]) async throws -> String {
        if spot.mode.stays, action == .read {
            let (script, frames, token) = stay(spot, limit: limit)
            tokens.setReason(ReadReason.panel.variables["OPENSPOT_REASON"], of: token)
            defer { script.end() }
            script.send(.read, variables: ReadReason.panel.variables.merging(variables) { _, new in new }, id: 1)
            for try await frame in frames where !SpotOutput(text: frame).isMark || SpotOutput(text: frame).ends.contains("1") { return frame }
            return ""
        }
        let (stream, halt, _) = frames(of: spot, action, input: input, limit: limit, variables: variables)
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
        let lines = await SpotOutput.reading(frame)
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

    func call(
        _ spot: Spot,
        _ action: SpotAction,
        key: String,
        input: String?,
        limit: TimeInterval?,
        reason: ReadReason? = nil,
        variables: [String: String] = [:],
        onFrame: @escaping @MainActor (ScriptCall, String, SpotOutput) async -> Void,
        onEnd: @escaping @MainActor (ScriptCall, ScriptCall.End) async -> Void
    ) -> ScriptCall {
        let call = ScriptCall(action: action, key: key, started: now())
        let (stream, halt, process) = frames(of: spot, action, input: input, limit: limit, variables: variables)
        call.halt = halt
        let id = spot.id
        let begin = Date()
        Task { [weak self] in
            var end = ScriptCall.End.ended
            var printed: [String] = []
            do {
                for try await frame in stream {
                    guard !call.isStopped else { break }
                    self?.add(frame, to: &printed)
                    guard let output = await self?.intake(frame, of: id), !call.isStopped else { break }
                    call.take(output)
                    await onFrame(call, frame, output)
                }
            } catch {
                end = .failed(error)
            }
            let ending: ScriptCall.End = call.isStopped ? .stopped : end
            self?.dropFinished()
            if let self { usage.called(spot, seconds: Date().timeIntervalSince(begin), isFailure: { if case .failed = ending { true } else { false } }(), at: now()) }
            if let process {
                self?.record(spot, action, input: input, frames: printed + (process.failedFrame.map { [$0] } ?? []), errors: process.errors, end: ending, reason: reason, started: call.started, begin: begin)
            }
            await onEnd(call, ending)
        }
        return call
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

    func inline(_ spot: Spot, limit: TimeInterval? = nil) -> InlineScript {
        let id = spot.id
        let idle = max(inlineIdle, (spot.read?.seconds ?? 0) * 1.5)
        return InlineScript(spot: spot, api: api, tokens: tokens, careful: isCareful ? spot.uses : nil, limit: limit ?? readLimit, idle: idle) { [usage] seconds in
            usage.add(ProcessTime(cpu: seconds, wakeups: 0), to: id, at: usage.now())
        }
    }

    func stay(_ spot: Spot, limit: TimeInterval?) -> (ScriptProcess, AsyncThrowingStream<String, Error>, String) {
        let token = tokens.issue(for: spot)
        let script = ScriptProcess(url: swift.runnable(for: spot.url), name: spot.url.path, mode: .stays, limit: limit, stopPause: stopPause, dataName: spot.dataName, variables: ["OPENSPOT_ID": spot.id, CallerTokens.variable: token], careful: isCareful ? spot.uses : nil)
        track(script, of: spot.id, token: token)
        let frames = script.start()
        keep(script)
        return (script, frames, token)
    }

    private func frames(of spot: Spot, _ action: SpotAction, input: String?, limit: TimeInterval?, variables: [String: String] = [:], withKeys: Bool = true) -> (stream: AsyncThrowingStream<String, Error>, halt: () -> Void, process: ScriptProcess?) {
        let isOwnRead = spot.listsKeysAbove && action.arguments.first == "read"
        if withKeys, isOwnRead, let keyList = spot.keyList {
            let own = frames(of: spot, action, input: input, limit: limit, variables: variables, withKeys: false)
            return (Self.prefixed(own.stream) { (try? keyList.answer(["read"])) ?? "" }, own.halt, own.process)
        }
        if !isOwnRead, let keyList = spot.keyList, keyList.answers(action.arguments) {
            let (stream, halt) = answered { try keyList.answer(action.arguments) }
            return (stream, halt, nil)
        }
        if let sheet = spot.host {
            let (stream, halt) = answered { try await sheet.answer(action.arguments) }
            return (stream, halt, nil)
        }
        if spot.mode == .inline {
            let script = inline(spot, limit: limit)
            let call = InlineCall(arguments: action.arguments, variables: variables, input: input)
            script.send(call)
            let (stream, halt) = answered {
                defer { script.end() }
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
        }
        let sent = action.sent(input: input)
        let token = tokens.issue(for: spot, reason: variables["OPENSPOT_REASON"])
        let process = ScriptProcess(url: swift.runnable(for: spot.url), name: spot.url.path, arguments: sent.arguments, mode: .once(input: sent.input), limit: limit, stopPause: stopPause, dataName: spot.dataName, variables: variables.merging(["OPENSPOT_ID": spot.id]) { given, _ in given }.merging([CallerTokens.variable: token]) { _, own in own }, careful: isCareful ? spot.uses : nil)
        track(process, of: spot.id, token: token)
        let stream = process.start()
        keep(process)
        return (stream, { process.stop() }, process)
    }

    static func joined(keys: String, own frame: String) -> String {
        let keyBlocks = TextBlock.blocks(in: keys)
        let ownBlocks = TextBlock.blocks(in: frame)
        func ids(_ blocks: [TextBlock]) -> [String] {
            blocks.compactMap { $0.fields.first?.key == "button" ? $0.fields.first?.value : nil }
        }
        let ownActions = ids(ownBlocks)
        let keyActions = ids(keyBlocks).filter { !ownActions.contains($0) }
        func hiding(_ actions: [String], pin: Bool) -> (TextBlock) -> TextBlock? {
            { block in
                guard let kind = block.fields.first?.key else { return block }
                if kind == "button", keyBlocks.contains(block), ownActions.contains(block.fields.first?.value ?? "") { return nil }
                guard kind == "row" else { return block }
                let place = block.value("shortcut") == KeyList.unset ? SpotItem.Pin.top : .bottom
                let pinned = pin ? [TextBlock.Field(key: "pin", value: place.rawValue)] : []
                return TextBlock(fields: block.fields + actions.map { TextBlock.Field(key: "hides", value: $0) } + pinned)
            }
        }
        func isHead(_ block: TextBlock) -> Bool {
            block.fields.first.map { !SpotOutput.isKind($0.key) && $0.key != "button" } ?? false
        }
        let ownHead = ownBlocks.first(where: isHead)
        let keyHead = keyBlocks.first(where: isHead)
        let headFields = (ownHead?.fields ?? []) + (keyHead?.fields ?? []).filter { field in ownHead?.value(field.key) == nil }
        let head = headFields.isEmpty ? [] : [TextBlock(fields: headFields)]
        let rest = ownBlocks.filter { !isHead($0) }.compactMap(hiding(keyActions, pin: false))
            + keyBlocks.filter { !isHead($0) }.compactMap(hiding(ownActions, pin: true))
        return (head + rest).map(\.text).joined(separator: "\n")
    }

    private static func prefixed(_ frames: AsyncThrowingStream<String, Error>, head: @escaping @Sendable () -> String) -> AsyncThrowingStream<String, Error> {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: String.self)
        let task = Task {
            let rows = head()
            var printed = false
            do {
                for try await frame in frames {
                    printed = true
                    continuation.yield(rows.isEmpty ? frame : Self.joined(keys: rows, own: frame))
                }
                if !printed, !rows.isEmpty { continuation.yield(rows) }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
        return stream
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

    func dropFinished() {
        processes.removeAll { !$0.needsFinish }
    }
}
