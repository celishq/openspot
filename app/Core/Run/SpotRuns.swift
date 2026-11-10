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
    @ObservationIgnored private var placedByFiles: Set<String> = []

    /// Each script that a widget file or a `spot` component of a card places, which the open panel reads.
    private var placed: Set<String> {
        placedByFiles.union(sheets.values.flatMap { $0.state.face.parts.filter { $0.kind == "spot" }.map(\.id) })
    }
    /// When the clock last read each script with a number in its `read`.
    @ObservationIgnored var asked: [String: Date] = [:]
    @ObservationIgnored var clock: Task<Void, Never>?
    @ObservationIgnored private var processes: [ScriptProcess] = []

    public init(
        readLimit: TimeInterval = 10,
        opening: SheetOpening = SheetOpening(),
        now: @escaping () -> Date = { Date() },
        stopPause: TimeInterval = 2,
        tickPause: Duration = .seconds(1),
        recent: @escaping (String) -> [String] = { _ in [] },
        prepare: @escaping ([SpotItem], [String]) async -> Void = { _, _ in }
    ) {
        self.readLimit = readLimit
        self.opening = opening
        self.now = now
        self.stopPause = stopPause
        self.tickPause = tickPause
        self.recent = recent
        self.prepare = prepare
    }

    nonisolated deinit {}

    /// Takes a new look at the plugin folder. Each script keeps its sheet, and a sheet whose script is gone stops its reads.
    /// A staying script that something wants starts.
    public func take(_ scan: ScanResult) {
        let scripts = scan.scripts
        placedByFiles = Set(scan.commands.flatMap(\.places))
        order = scripts.map(\.id)
        for (id, sheet) in sheets where !order.contains(id) {
            sheets[id] = nil
            if sheet.isOpen { onReport(id, .closed) }
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
        arrive(.panel)
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
        sheets.values.forEach { $0.panelClosed() }
        updateClock()
    }

    /// A moment arrived: reads each script whose `read` lists it, all at the same time. Only `panel` can use a young answer.
    /// A staying script that something wants and that ended starts again.
    public func arrive(_ moment: SpotRead.Moment) {
        let reason: ReadReason = switch moment {
        case .launch: .launch
        case .wake: .wake
        case .sheet: .sheet
        case .panel, .every: .panel
        }
        for sheet in sheets.values where sheet.command.read?.has(moment) == true {
            sheet.read(need: moment == .panel ? .moment : .clock, reason: reason)
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
            guard let sheet = sheets[id], sheet.command.isTray, let mark = TrayMark(reading: sheet.reading) else { return nil }
            return (id, mark)
        }
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
            let (script, frames) = try stay(command, limit: limit)
            defer { script.end() }
            script.send(.read, id: 1, reason: .panel)
            for try await frame in frames { return frame }
            return ""
        }
        let (stream, halt) = frames(of: command, action, input: input, limit: limit)
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
        guard let read = command.read else { return command.isTray }
        return command.isTray || read.has(.launch) || (isPanelOpen && (read.has(.panel) || placed.contains(command.id)))
    }

    /// Reads a frame of a script, on another thread when it is big, and waits while the open motion of its sheet runs. The
    /// sheet hears a frame that waits, so that it can say its kind before the frame shows.
    func intake(_ frame: String, of id: String?) async -> PluginOutput {
        let lines = await PluginOutput.reading(frame)
        guard let id, opening.moving == id else { return lines }
        sheets[id]?.hear(lines)
        await opening.waitForMotion(of: id)
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
        let (stream, halt) = frames(of: command, action, input: input, limit: limit, variables: variables)
        call.halt = halt
        let id = command.id
        Task { [weak self] in
            var end = ScriptCall.End.ended
            do {
                for try await frame in stream {
                    guard !call.isStopped else { break }
                    guard let output = await self?.intake(frame, of: id), !call.isStopped else { break }
                    call.take(output)
                    await onFrame(call, frame, output)
                }
            } catch {
                end = .failed(error)
            }
            await onEnd(call, call.isStopped ? .stopped : end)
        }
        return call
    }

    /// Starts a script that stays, and returns it with its frames.
    func stay(_ command: Spot, limit: TimeInterval?) throws -> (ScriptProcess, AsyncThrowingStream<String, Error>) {
        let script = ScriptProcess(url: SwiftProgram.file(beside: command.url) ?? command.url, mode: .stays, limit: limit, stopPause: stopPause, dataName: command.dataName, variables: ["OPENSPOT_ID": command.id])
        let frames = try script.start()
        keep(script)
        return (script, frames)
    }

    private func frames(of command: Spot, _ action: SpotAction, input: String?, limit: TimeInterval?, variables: [String: String] = [:]) -> (stream: AsyncThrowingStream<String, Error>, halt: () -> Void) {
        if let shipped = command.keyList.flatMap({ $0.answers(action.arguments) ? ShippedSpot.settings($0) : nil }) ?? command.shipped {
            return answered { try await shipped.answer(action.arguments, input: input) }
        }
        let sent = action.sent(input: input)
        let process = ScriptProcess(url: SwiftProgram.file(beside: command.url) ?? command.url, arguments: sent.arguments, mode: .once(input: sent.input), limit: limit, stopPause: stopPause, dataName: command.dataName, variables: variables.merging(["OPENSPOT_ID": command.id]) { given, _ in given })
        do {
            let stream = try process.start()
            keep(process)
            return (stream, { process.stop() })
        } catch {
            return (AsyncThrowingStream { $0.finish(throwing: error) }, {})
        }
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
