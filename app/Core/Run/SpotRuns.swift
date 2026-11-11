import Foundation
import Observation

/// The one owner of all runs. It holds one sheet for each script, starts each process, knows what wants a script, and
/// stops each call when the app quits.
@MainActor
@Observable
public final class SpotRuns {
    public private(set) var sheets: [String: SpotRun] = [:]
    public private(set) var isPanelOpen = false
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
    /// The time a `read` has to its first frame or its end.
    public let readLimit: TimeInterval
    @ObservationIgnored let now: () -> Date
    @ObservationIgnored private let stopPause: TimeInterval
    @ObservationIgnored let tickPause: Duration
    @ObservationIgnored private let recent: (String) -> [String]
    @ObservationIgnored private let prepare: ([SpotItem], [String]) async -> Void
    private var order: [String] = []

    /// Each script that a widget file places, which the open panel reads.
    @ObservationIgnored private var placed: Set<String> = []
    /// Each script that the person put in the menu bar.
    private var menuBar: Set<String> = []
    /// When the clock last read each script with a number in its `read`.
    @ObservationIgnored var asked: [String: Date] = [:]
    @ObservationIgnored var clock: Task<Void, Never>?
    @ObservationIgnored private var processes: [ScriptProcess] = []
    /// The record of each call that runs once, or nil to keep none.
    @ObservationIgnored private let log: CallLog?

    public init(
        readLimit: TimeInterval = 10,
        opening: SheetOpening = SheetOpening(),
        now: @escaping () -> Date = { Date() },
        stopPause: TimeInterval = 2,
        tickPause: Duration = .seconds(1),
        recent: @escaping (String) -> [String] = { _ in [] },
        prepare: @escaping ([SpotItem], [String]) async -> Void = { _, _ in },
        log: CallLog? = nil
    ) {
        self.log = log
        self.readLimit = readLimit
        self.opening = opening
        self.now = now
        self.stopPause = stopPause
        self.tickPause = tickPause
        self.recent = recent
        self.prepare = prepare
    }

    nonisolated deinit {}

    /// Takes a new look at the plugin folder, with the spots that the person put in the menu bar. Each script keeps its sheet,
    /// and a sheet whose script is gone stops its reads. A staying script that something wants starts.
    public func take(_ scan: ScanResult, menuBar: Set<String> = []) {
        let scripts = scan.scripts
        placed = Set(scan.commands.flatMap(\.places))
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
        updateClock()
    }

    /// The sheet of a script, with the command as the folder last gave it.
    public func sheet(for command: Spot) -> SpotRun {
        if let sheet = sheets[command.id] {
            sheet.update(command)
            return sheet
        }
        let id = command.id
        let sheet = SpotRun(command: command, runs: self, recent: recent(id), prepare: prepare)
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
        let id = sheet.command.id
        if let open = openID, open != id { sheets[open]?.close() }
        openID = id
    }

    func didClose(_ sheet: SpotRun) {
        if openID == sheet.command.id { openID = nil }
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

    /// The panel opened: reads each script that this moment lists or that a widget places, and starts the timers.
    public func panelOpened() {
        let wasOpen = isPanelOpen
        isPanelOpen = true
        if !wasOpen { sheets.values.forEach { $0.panelOpened() } }
        tick()
        readPanel()
        for id in placed {
            if let sheet = sheets[id], sheet.command.read?.seconds == nil { sheet.read() }
        }
        updateClock()
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

    /// Reads each script with `panel` in its `read`, all at the same time, each of which can use a young answer. A staying
    /// script that something wants and that ended starts again.
    private func readPanel() {
        for sheet in sheets.values where sheet.command.read?.has(.panel) == true {
            sheet.read(need: .moment, reason: .panel)
        }
        sheets.values.forEach { $0.settleScript() }
    }

    /// The Mac woke: each wanted script with a number in its `read` reads at once, and its clock starts again from now. A
    /// staying script that something wants and that ended starts again.
    public func woke() {
        let time = now()
        for sheet in sheets.values where sheet.isWanted && sheet.command.read?.seconds != nil {
            asked[sheet.command.id] = time
            sheet.read(need: .clock, reason: .timer)
        }
        sheets.values.forEach { $0.settleScript() }
    }

    /// Stops each call, which changes nothing, and waits for the processes to end, for at most 2 seconds.
    public func quit() {
        clock?.cancel()
        clock = nil
        opening.end()
        let live = processes.filter(\.needsFinish)
        sheets.values.forEach { $0.prepareToQuit() }
        live.forEach { $0.leave() }
        let deadline = Date().addingTimeInterval(stopPause)
        live.forEach { $0.finish(by: deadline) }
    }

    /// The marks of the scripts that show in the menu bar, in the order of the folder.
    public var trayMarks: [(id: String, mark: TrayMark)] {
        order.compactMap { id in
            guard let sheet = sheets[id], isInMenuBar(sheet.command), let mark = TrayMark(reading: sheet.reading) else { return nil }
            return (id, mark)
        }
    }

    /// Whether the menu bar shows this script: the person put it there, and it can show there.
    private func isInMenuBar(_ command: Spot) -> Bool {
        menuBar.contains(command.id) && command.canShowInMenuBar
    }

    /// The running work of all scripts, the oldest first, with the ID of each script.
    public var work: [(id: String, call: ScriptCall)] {
        order.flatMap { id in (sheets[id]?.work ?? []).map { (id: id, call: $0) } }.sorted { $0.call.started < $1.call.started }
    }

    /// What the Openspot item shows for running work, or nothing when none shows.
    public var workMark: TrayMark? {
        let work = work
        guard let oldest = work.first else { return nil }
        return TrayMark(workFill: oldest.call.fill, count: work.count, name: sheets[oldest.id]?.command.name ?? oldest.id)
    }

    /// The ID of the script of the oldest running work, whose spot a click on the Openspot item selects.
    public var workSpot: String? {
        work.first?.id
    }

    /// Whether the card of this script takes all the files of the drag in progress.
    public func takesDrag(_ id: String) -> Bool {
        sheets[id]?.command.accepts(draggedPaths) == true
    }

    /// Runs one call with no sheet, and returns all that it prints. A `read` runs until it gives its first frame, which is what
    /// a sheet takes as its answer.
    public func answer(of command: Spot, _ action: SpotAction, input: String? = nil, limit: TimeInterval? = nil) async throws -> String {
        if command.stays, action == .read {
            let (script, frames) = stay(command, limit: limit)
            defer { script.end() }
            script.send(.read, id: 1, reason: .panel)
            for try await frame in frames { return frame }
            return ""
        }
        let (stream, halt, _) = frames(of: command, action, input: input, limit: limit)
        if action == .read {
            defer { halt() }
            for try await frame in stream { return frame }
            return ""
        }
        var text = ""
        for try await frame in stream { text += frame }
        return text
    }

    /// Whether something other than its sheet in view wants this script.
    func wants(_ command: Spot) -> Bool {
        if isInMenuBar(command) || command.staysAlways { return true }
        guard let read = command.read else { return false }
        return isPanelOpen && (read.has(.panel) || placed.contains(command.id))
    }

    /// Reads a frame of a script on another thread, and waits while the open motion of its sheet runs. The
    /// sheet hears the frame while it waits, so that it can say its kind before the frame shows or its call drops it.
    func intake(_ frame: String, of id: String?) async -> PluginOutput {
        let lines = await PluginOutput.reading(frame)
        guard let id, opening.moving == id else { return lines }
        sheets[id]?.hear(lines)
        await opening.waitForMotion(of: id)
        sheets[id]?.hear(nil)
        return lines
    }

    /// Starts one call. It gives each frame, as text and sorted by what each block is, and then its end, on the main actor. A
    /// frame waits for the open motion of its sheet, and one that its call stopped meanwhile changes nothing.
    func call(
        _ command: Spot,
        _ action: SpotAction,
        key: String,
        input: String?,
        limit: TimeInterval?,
        variables: [String: String] = [:],
        onFrame: @escaping @MainActor (ScriptCall, String, PluginOutput) async -> Void,
        onEnd: @escaping @MainActor (ScriptCall, ScriptCall.End) async -> Void
    ) -> ScriptCall {
        let call = ScriptCall(action: action, key: key, started: now())
        let (stream, halt, process) = frames(of: command, action, input: input, limit: limit, variables: variables)
        call.halt = halt
        let id = command.id
        let begin = Date()
        Task { [weak self, log] in
            var end = ScriptCall.End.ended
            var printed: [String] = []
            do {
                for try await frame in stream {
                    guard !call.isStopped else { break }
                    log?.add(frame, to: &printed)
                    guard let output = await self?.intake(frame, of: id), !call.isStopped else { break }
                    call.take(output)
                    await onFrame(call, frame, output)
                }
            } catch {
                end = .failed(error)
            }
            let ending: ScriptCall.End = call.isStopped ? .stopped : end
            if let log, let process {
                log.write(CallLog.Record(
                    spot: command.id,
                    arguments: action.arguments,
                    input: input,
                    frames: printed + (process.failedFrame.map { [$0] } ?? []),
                    errors: process.errors,
                    end: CallLog.End(ending),
                    started: call.started,
                    seconds: Date().timeIntervalSince(begin)
                ))
            }
            await onEnd(call, ending)
        }
        return call
    }

    /// Starts a script that stays, and returns it with its frames.
    func stay(_ command: Spot, limit: TimeInterval?) -> (ScriptProcess, AsyncThrowingStream<String, Error>) {
        let script = ScriptProcess(url: SwiftProgram.file(beside: command.url) ?? command.url, mode: .stays, limit: limit, stopPause: stopPause, dataName: command.dataName, variables: ["OPENSPOT_ID": command.id])
        let frames = script.start()
        keep(script)
        return (script, frames)
    }

    private func frames(of command: Spot, _ action: SpotAction, input: String?, limit: TimeInterval?, variables: [String: String] = [:]) -> (stream: AsyncThrowingStream<String, Error>, halt: () -> Void, process: ScriptProcess?) {
        if let shipped = command.keyList.flatMap({ $0.answers(action.arguments) ? ShippedSpot.settings($0) : nil }) ?? command.shipped {
            let (stream, halt) = answered { try await shipped.answer(action.arguments, input: input) }
            return (stream, halt, nil)
        }
        let sent = action.sent(input: input)
        let process = ScriptProcess(url: SwiftProgram.file(beside: command.url) ?? command.url, arguments: sent.arguments, mode: .once(input: sent.input), limit: limit, stopPause: stopPause, dataName: command.dataName, variables: variables.merging(["OPENSPOT_ID": command.id]) { given, _ in given })
        let stream = process.start()
        keep(process)
        return (stream, { process.stop() }, process)
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

    private func keep(_ process: ScriptProcess) {
        processes.removeAll { !$0.needsFinish }
        processes.append(process)
    }
}
