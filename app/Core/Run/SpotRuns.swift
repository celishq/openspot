import Foundation
import Observation

/// The one owner of all runs. It holds one sheet for each script, starts each process, knows what wants a script, and
/// stops each call when the app quits.
@MainActor
@Observable
public final class SpotRuns {
    public private(set) var sheets: [String: SpotRun] = [:]
    public internal(set) var isPanelOpen = false
    /// The script whose sheet is open: the one record of it. A sheet that opens closes the one before.
    public private(set) var openID: String?
    /// The scripts that float in windows of their own. Each one is in view while it floats (W7).
    public private(set) var floating: Set<String> = []
    /// The files of the drag in progress, which each card that takes them all shows for the whole drag.
    public var draggedPaths: [String] = []
    @ObservationIgnored public var onReport: (String, SpotRun.Report) -> Void = { _, _ in }
    /// Makes the change that brings a sheet its first parts, so that the shell can move the sheet to its new size.
    @ObservationIgnored public var partsArrival: (String, () -> Void) -> Void = { _, bring in bring() }
    /// The open of a sheet: its motion waits for its first answer, and what its script prints waits for its motion.
    @ObservationIgnored public let opening: SheetOpening
    /// The time a `read` has to its first frame or its end, and a call of an inline spot has to its end (protocol: Modes).
    public let readLimit: TimeInterval
    /// The time with no call after which an inline spot lets go of its context and its thread (A26).
    let inlineIdle: TimeInterval
    /// What each spot cost and used, day by day (protocol: Stats).
    public nonisolated let usage: SpotUsage
    /// Whether each process of a spot runs in Careful mode, with only what its uses name (protocol: Trust). A change starts each staying
    /// script again in the new mode, and each inline script at its next call.
    @ObservationIgnored public var isCareful = false {
        didSet {
            tokens.isCareful = isCareful
            guard isCareful != oldValue else { return }
            sheets.values.forEach { $0.restartScript() }
        }
    }
    /// The token of each process and inline link that runs, by which the API knows a spot's call (protocol: Trust).
    public nonisolated let tokens: CallerTokens
    @ObservationIgnored let now: () -> Date
    @ObservationIgnored private let stopPause: TimeInterval
    @ObservationIgnored let tickPause: Duration
    /// The time between two looks at the clipboard, while a spot lists `clipboard`.
    @ObservationIgnored let clipboardPause: Duration
    /// What raises the events of the Mac, once the app gives it.
    @ObservationIgnored var source: (any Mac)?
    /// The looks at the clipboard, which run only while a spot lists `clipboard`.
    @ObservationIgnored var clipboardWatch: Task<Void, Never>?
    /// Whether the app quit, after which nothing starts.
    @ObservationIgnored private(set) var hasQuit = false
    @ObservationIgnored private let recent: (String) -> [String]
    @ObservationIgnored private let prepare: ([SpotItem], [String]) async -> Void
    private var order: [String] = []

    /// Each script that a widget file places, which the open panel reads.
    @ObservationIgnored private(set) var placed: Set<String> = []
    /// Each script that the person put in the menu bar.
    private var menuBar: Set<String> = []
    /// When the clock last read each script with a number in its `read`.
    @ObservationIgnored var asked: [String: Date] = [:]
    @ObservationIgnored var clock: Task<Void, Never>?
    /// The seconds until the next timed read, as the last tick of the clock found them, or nil when no wanted script has a
    /// number in its `read`.
    @ObservationIgnored var nextRead: TimeInterval?
    /// Which `answers` patterns match the text of the main search.
    @ObservationIgnored var answerMatches = AnswerMatches()
    @ObservationIgnored private var processes: [ScriptProcess] = []
    /// The API in the app, which `openspot.call` of a JavaScript spot asks, or nil to run the `openspot` command.
    @ObservationIgnored public var api: CommandAPI?
    /// The record of each call that runs once, or nil to keep none.
    @ObservationIgnored private let log: CallLog?
    /// Hears each call that ends, quiet ones too, with the reason of a read, such as the playground that shows each call.
    @ObservationIgnored public var onCall: ((CallLog.Record, ReadReason?) -> Void)?
    /// The builds of Swift scripts, which each process runs once they are ready.
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

    /// Takes a new look at the plugin folder, with the spots that the person put in the menu bar. Each script keeps its sheet,
    /// and a sheet whose script is gone stops its reads. A staying script that something wants starts. At most once a day, it
    /// prunes the builds of Swift scripts.
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
    }

    /// The sheet of a script, with the spot as the folder last gave it.
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

    /// Records the sheet that opens, and closes the one before.
    func willOpen(_ sheet: SpotRun) {
        let id = sheet.spot.id
        if let open = openID, open != id { sheets[open]?.close() }
        openID = id
    }

    func didClose(_ sheet: SpotRun) {
        if openID == sheet.spot.id { openID = nil }
    }

    /// Shows a script in a float, where its sheet reads as an open sheet does (W7).
    public func float(_ id: String) {
        guard let sheet = sheets[id], floating.insert(id).inserted else { return }
        sheet.floated()
    }

    /// Ends the float of a script. A sheet of parts with a field drops its values, as the panel's close does (K5).
    public func land(_ id: String) {
        guard floating.remove(id) != nil else { return }
        sheets[id]?.leftPlace()
        updateClock()
    }

    /// Closes the open sheet.
    public func closeOpen() {
        openID.flatMap { sheets[$0] }?.close()
    }

    /// Whether a read of any script runs.
    public var isReading: Bool {
        sheets.values.contains(where: \.isReading)
    }

    /// The panel closed: a sheet of parts closes, one with a field drops its values, and a read that nothing wants now stops.
    public func panelClosed() {
        isPanelOpen = false
        sheets.values.forEach { $0.leftPlace() }
        updateClock()
    }

    /// Stops each call, which changes nothing, and waits for the processes to end, for at most 2 seconds.
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

    /// The marks of the scripts that show in the menu bar, in the order of the folder.
    public var trayMarks: [(id: String, mark: TrayMark)] {
        order.compactMap { id in
            guard let sheet = sheets[id], isInMenuBar(sheet.spot), let mark = TrayMark(reading: sheet.reading) else { return nil }
            return (id, mark)
        }
    }

    /// Whether the menu bar shows this script: the person put it there, and it can show there.
    private func isInMenuBar(_ spot: Spot) -> Bool {
        menuBar.contains(spot.id) && spot.canShowInMenuBar
    }

    /// The running work of all scripts, the oldest first, with the ID of each script.
    public var work: [(id: String, call: ScriptCall)] {
        order.flatMap { id in (sheets[id]?.work ?? []).map { (id: id, call: $0) } }.sorted { $0.call.started < $1.call.started }
    }

    /// What the Openspot item shows for running work, or nothing when none shows.
    public var workMark: TrayMark? {
        let work = work
        guard let oldest = work.first else { return nil }
        return TrayMark(workFill: oldest.call.fill, count: work.count, name: sheets[oldest.id]?.spot.name ?? oldest.id)
    }

    /// The ID of the script of the oldest running work, whose spot a click on the Openspot item selects.
    public var workSpot: String? {
        work.first?.id
    }

    /// Whether the card of this script takes all the files of the drag in progress.
    public func takesDrag(_ id: String) -> Bool {
        sheets[id]?.spot.accepts(draggedPaths) == true
    }

    /// Runs one call with no sheet, with `variables` added to its environment, and returns all that it prints. A `read` runs
    /// until it gives its first frame, which is what a sheet takes as its answer.
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

    /// Whether something other than its sheet in view wants this script. The open panel wants a staying script that answers
    /// its search.
    func wants(_ spot: Spot) -> Bool {
        if isInMenuBar(spot) || spot.mode == .always { return true }
        if isPanelOpen, spot.mode.stays, spot.answers != nil { return true }
        guard let read = spot.read else { return false }
        return isPanelOpen && (read.has(.panel) || placed.contains(spot.id))
    }

    /// Reads a frame of a script on another thread, and waits while the open motion of its sheet runs. The
    /// sheet hears the frame while it waits, so that it can say its kind before the frame shows or its call drops it.
    func intake(_ frame: String, of id: String?) async -> SpotOutput {
        let lines = await SpotOutput.reading(frame)
        guard let id, opening.moving == id else { return lines }
        sheets[id]?.hear(lines)
        await opening.waitForMotion(of: id)
        sheets[id]?.hear(nil)
        return lines
    }

    /// Whether a call leaves no record: a timed read, a read of an event or a search that did not fail, which runs too often
    /// to keep.
    private static func isQuiet(_ reason: ReadReason?, _ end: ScriptCall.End) -> Bool {
        guard reason?.isFrequent == true else { return false }
        if case .failed = end { return false }
        return true
    }

    /// Starts one call. It gives each frame, as text and sorted by what each block is, and then its end, on the main actor. A
    /// frame waits for the open motion of its sheet, and one that its call stopped meanwhile changes nothing.
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
        Task { [weak self, log] in
            var end = ScriptCall.End.ended
            var printed: [String] = []
            do {
                for try await frame in stream {
                    guard !call.isStopped else { break }
                    if let log { log.add(frame, to: &printed) } else if self?.onCall != nil { printed.append(frame) }
                    guard let output = await self?.intake(frame, of: id), !call.isStopped else { break }
                    call.take(output)
                    await onFrame(call, frame, output)
                }
            } catch {
                end = .failed(error)
            }
            let ending: ScriptCall.End = call.isStopped ? .stopped : end
            if let self { usage.called(spot, seconds: Date().timeIntervalSince(begin), isFailure: { if case .failed = ending { true } else { false } }(), at: now()) }
            if let process {
                self?.record(spot, action, input: input, frames: printed + (process.failedFrame.map { [$0] } ?? []), errors: process.errors, end: ending, reason: reason, started: call.started, begin: begin)
            }
            await onEnd(call, ending)
        }
        return call
    }

    /// Keeps the record of a call that ended in the call log, unless it is a quiet one.
    func record(_ spot: Spot, _ action: SpotAction, input: String?, frames: [String], errors: String, end: ScriptCall.End, reason: ReadReason?, started: Date, begin: Date) {
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

    /// A JavaScript spot of these runs, which loads at its first call and counts the CPU time of its thread (A26).
    func inline(_ spot: Spot, limit: TimeInterval? = nil) -> InlineScript {
        let id = spot.id
        return InlineScript(spot: spot, api: api, tokens: tokens, careful: isCareful ? spot.uses : nil, limit: limit ?? readLimit, idle: inlineIdle) { [usage] seconds in
            usage.add(ProcessTime(cpu: seconds, wakeups: 0), to: id, at: usage.now())
        }
    }

    /// Starts a script that stays, and returns it with its frames and the token of its spot, whose reason its link keeps.
    func stay(_ spot: Spot, limit: TimeInterval?) -> (ScriptProcess, AsyncThrowingStream<String, Error>, String) {
        let token = tokens.issue(for: spot)
        let script = ScriptProcess(url: swift.runnable(for: spot.url), name: spot.url.path, mode: .stays, limit: limit, stopPause: stopPause, dataName: spot.dataName, variables: ["OPENSPOT_ID": spot.id, CallerTokens.variable: token], careful: isCareful ? spot.uses : nil)
        track(script, of: spot.id, token: token)
        let frames = script.start()
        keep(script)
        return (script, frames, token)
    }

    /// The frames of one call. A read of a spot that lists its keys beside its own rows joins the two, unless `withKeys` is
    /// false.
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

    /// A frame of the script with the key rows after its rows, pinned at the top while they have no key and at the bottom once
    /// they have one, so a row that the script pins at the top comes first. The two heads become one, and the script's keys
    /// win, such as `search=off`. Each row keeps only its own actions: a key row hides the
    /// script's, and a row of the script hides the keys', so a shortcut that both use, such as ⌘⌫, acts on the right row.
    /// An action of the script wins over a key action of the same id.
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

    /// The frames of a script with the rows of `head` above each, and those rows alone when the script prints no frame.
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

    /// The frames of an answer that Swift gives in the app: one frame with all its text.
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

    /// Takes a spot's call that needs a use, and shows a toast at its first use of the day that its header does not name (protocol: Trust).
    func used(_ call: SpotUseCall, by caller: CallerTokens.Caller) {
        guard usage.used(call, by: caller, at: now()) else { return }
        onReport(caller.id, .toast("\(caller.name) \(call.words) without `uses=\(call.use.rawValue)` in its header. Add it to stop this note."))
    }

    /// Counts the time of a process of a spot, ties its token to its process group, and lets go of the token once the group
    /// ends.
    private func track(_ process: ScriptProcess, of spot: String, token: String) {
        usage.track(process, of: spot)
        process.onStart { [tokens] group in tokens.enter(group, token: token) }
        process.onExit { [tokens] _ in tokens.release(token) }
    }

    private func keep(_ process: ScriptProcess) {
        processes.removeAll { !$0.needsFinish }
        processes.append(process)
    }
}
