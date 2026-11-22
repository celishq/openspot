import Foundation

@MainActor
final class StayMode: ScriptMode {
    @MainActor
    final class Record {
        let call: OpenCall
        var isDropped = false
        var isPictured = false
        var timer: Task<Void, Never>?
        var deadline: Date?
        var left: TimeInterval?

        init(_ call: OpenCall) {
            self.call = call
        }

        var ask: SpotRun.Ask? {
            guard !isDropped, case .ask(let ask) = call.request.purpose else { return nil }
            return ask
        }

        var isForm: Bool {
            guard !isDropped, case .form = call.request.purpose else { return false }
            return true
        }

        var isAct: Bool {
            guard !isDropped, case .act = call.request.purpose else { return false }
            return true
        }
    }

    private static let failureLimit = 3
    private static let failureWindow: TimeInterval = 60
    private static let slowLimit = 2
    static let droppedLimit = 100

    weak var run: SpotRun?
    private let runs: SpotRuns
    private var script: ScriptProcess?
    private var caller: SpotCaller?
    private(set) var records: [Int: Record] = [:]
    private var droppedBelow = 0
    private var askReason: String?
    private var lastPicture: Frame?
    private var printing: Int?
    private var drawn: (call: Int?, text: String?)?
    private var count = 0
    private var failures: [Date] = []
    private var stamp: [Int]?
    private var givenUp: [Int]??
    private var heldScript = false
    private var slowAsks = 0
    private var endingAsks = 0
    private var isHeld = false
    private var asksAfterHold = false

    init(runs: SpotRuns) {
        self.runs = runs
    }

    nonisolated deinit {}

    static var keepsState: Bool {
        true
    }

    static func answer(of spot: Spot, _ action: SpotAction, input: String?, limit: TimeInterval?, variables: [String: String], in runs: SpotRuns) async throws -> String {
        guard action == .show else { return try await collect(of: spot, action, input: input, limit: limit, variables: variables, in: runs) }
        let (script, frames, caller) = runs.stay(spot, limit: limit)
        caller.reason = ShowEvent.panel.rawValue
        defer { script.end() }
        script.send(Message(.show, event: .panel, given: input).handled(), id: 1)
        for try await frame in frames {
            let head = FrameRoot(text: frame)
            if !head.isMark || head.end == "1" { return frame }
        }
        return ""
    }

    var isAsking: Bool {
        endingAsks > 0 || records.values.contains { $0.ask.map { !$0.isAnswer } ?? false }
    }

    private var holdsScript: Bool {
        records.values.contains { $0.isAct || $0.isForm }
    }

    func send(_ call: OpenCall) -> Bool {
        if case .ask(let ask) = call.request.purpose, let run, runs.waitsInRun(run.spot.id) {
            if case .answer(let text) = ask {
                run.takeAnswers(run.answers, to: text)
                asksAfterHold = true
            }
            return false
        }
        switch call.request.purpose {
        case .ask(.show):
            guard run?.isWanted == true else { return false }
            guard let script else {
                start(event: call.request.event)
                return self.script != nil
            }
            open(call, on: script, isTimed: true)
        case .ask(.search):
            stop { if case .search = $0 { true } else { false } }
            post(call, isTimed: true)
        case .ask(.answer(let text)):
            stop(\.isAnswer)
            if !post(call, isTimed: true) { run?.takeAnswers([], to: text) }
        case .act(let act):
            call.request.purpose = .act(SpotRun.Act(keeping: act.keeping, showsAfter: false, undo: act.undo, first: act.first))
            if post(call, isTimed: false) { run?.track(call.made) }
        case .form:
            guard !records.values.contains(where: \.isForm), post(call, isTimed: call.request.chain.isEmpty) else { return false }
            run?.track(call.made)
        }
        settle()
        return script != nil
    }

    func stop(_ call: ScriptCall) {
        guard let (id, record) = records.first(where: { $0.value.call.made === call && !$0.value.isDropped }) else { return }
        drop(id)
        run?.finish(record.call, .stopped)
    }

    func settle() {
        let isNeeded = run?.isWanted == true
        if isNeeded, script == nil { start() }
        if !isNeeded, script != nil { end() }
        guard holdsScript != heldScript else { return }
        heldScript = holdsScript
        runs.updateClock()
    }

    func restart() {
        guard script != nil else { return }
        end(because: "Openspot restarted it")
        settle()
    }

    func end() {
        script?.end()
        script = nil
        loseAll(.stopped)
        run?.scriptEnded()
    }

    private func end(because why: String) {
        let held = records.values.contains(where: \.isAct)
        end()
        guard held, let run else { return }
        run.onReport(.toast("\(run.spot.name) stopped, since \(why). Start it again to go on."))
    }

    func leave() {
        script = nil
        loseAll(.stopped)
    }

    func scanned(_ stamp: [Int]?) {
        self.stamp = stamp
        if let givenUp, stamp != givenUp {
            self.givenUp = nil
            failures = []
        }
        settle()
    }

    private var startEvent: ShowEvent {
        guard let run else { return .panel }
        return !run.places.isEmpty ? .sheet : .panel
    }

    private func start(event: ShowEvent? = nil) {
        guard let run, givenUp == nil else { return }
        let (script, frames, caller) = runs.stay(run.spot, limit: runs.showLimit)
        self.script = script
        self.caller = caller
        drawn = nil
        slowAsks = 0
        let event = event ?? startEvent
        let show = SpotRun.Call(message: Message(.show), key: SpotRun.showKey, event: event, purpose: .ask(.show(generation: nil, reports: true)))
        open(OpenCall(show, started: runs.now()), on: script, isTimed: false)
        Task { await follow(script, frames) }
    }

    private func post(_ call: OpenCall, isTimed: Bool) -> Bool {
        if script == nil { start() }
        guard let script else {
            settle()
            return false
        }
        open(call, on: script, isTimed: isTimed)
        return true
    }

    private func open(_ call: OpenCall, on script: ScriptProcess, isTimed: Bool) {
        count += 1
        let id = count
        let record = Record(call)
        let request = call.request
        records[id] = record
        call.made.halt = { [weak script] in script?.send(text: SpotAction.stopEvent(id: id)) }
        if case .ask = request.purpose { askReason = request.event?.rawValue }
        caller?.call = call
        noteReason()
        script.send(run.map { $0.message(of: request, values: $0.fieldValues) } ?? request.message, id: id)
        guard isTimed else { return }
        if isHeld {
            record.left = runs.showLimit
        } else {
            arm(id, record, for: runs.showLimit, on: script)
        }
    }

    private func arm(_ id: Int, _ record: Record, for limit: TimeInterval, on script: ScriptProcess) {
        record.deadline = runs.now().addingTimeInterval(limit)
        record.timer = Task { [weak self, weak script, sleep = runs.clock.sleep] in
            try? await sleep(.seconds(limit), .seconds(limit / 10))
            guard !Task.isCancelled, let script else { return }
            self?.timeOut(id, of: script)
        }
    }

    func holdLimit() {
        isHeld = true
        let now = runs.now()
        for record in records.values where !record.isDropped {
            guard let timer = record.timer, let deadline = record.deadline else { continue }
            timer.cancel()
            record.timer = nil
            record.left = max(0, deadline.timeIntervalSince(now))
        }
    }

    func releaseLimit() {
        isHeld = false
        if let script {
            for (id, record) in records where !record.isDropped {
                guard let left = record.left else { continue }
                record.left = nil
                arm(id, record, for: left, on: script)
            }
        }
        guard asksAfterHold else { return }
        asksAfterHold = false
        run?.askAnswer()
    }

    private func noteReason() {
        guard let caller else { return }
        let asks = records.values.contains { $0.ask != nil }
        caller.reason = asks && !holdsScript ? askReason : nil
    }

    private func timeOut(_ id: Int, of script: ScriptProcess) {
        guard self.script === script, let record = records[id], !record.isDropped else { return }
        let isAsk = record.ask != nil
        drop(id)
        if isAsk { slowAsks += 1 }
        run?.finish(record.call, .failed(SpotError.timedOut))
        if isAsk, slowAsks >= Self.slowLimit {
            end(because: "it answered too slowly")
            failed(SpotError.timedOut, telling: false)
        }
        settle()
    }

    private func stop(_ kind: (SpotRun.Ask) -> Bool) {
        for (id, record) in records {
            guard let ask = record.ask, kind(ask) else { continue }
            drop(id)
            run?.finish(record.call, .stopped)
        }
    }

    private func drop(_ id: Int) {
        guard let record = records[id] else { return }
        record.call.made.stop()
        record.isDropped = true
        record.timer?.cancel()
        record.timer = nil
        let dropped = records.filter(\.value.isDropped).keys
        if dropped.count > Self.droppedLimit, let oldest = dropped.min() {
            records[oldest] = nil
            droppedBelow = max(droppedBelow, oldest + 1)
        }
        noteReason()
    }

    private func remove(_ id: Int) {
        records.removeValue(forKey: id)?.timer?.cancel()
        noteReason()
    }

    private func isDropped(_ id: Int) -> Bool {
        records[id]?.isDropped ?? (id < droppedBelow)
    }

    private func loseAll(_ end: ScriptCall.End, errors: String = "") {
        let lost = records.sorted { $0.key < $1.key }.map(\.value)
        lost.forEach { $0.timer?.cancel() }
        records = [:]
        printing = nil
        noteReason()
        for record in lost where !record.isDropped { run?.lose(record.call, end, errors: errors) }
    }

    private var searches: Set<String> {
        Set(records.compactMap { id, record in
            switch record.ask {
            case .search?, .answer?: String(id)
            default: nil
            }
        })
    }

    private func follow(_ script: ScriptProcess, _ frames: AsyncThrowingStream<String, Error>) async {
        var failure: Error?
        do {
            for try await frame in frames {
                let call = printing
                let next = await FrameStream.next(frame, after: drawn?.call == call ? drawn?.text : nil, apart: searches)
                drawn = (call, next.drawn)
                let text = next.text
                let lines = await runs.intake(text, of: run?.spot)
                guard self.script === script, let run else { continue }
                await take(text, lines, in: run)
            }
        } catch {
            failure = error
        }
        runs.dropFinished()
        guard self.script === script else { return }
        self.script = nil
        if let failure {
            failed(failure)
            loseAll(.failed(failure), errors: script.errors)
        } else {
            loseAll(.ended, errors: script.errors)
        }
        run?.lost()
    }

    private func take(_ text: String, _ lines: Frame, in run: SpotRun) async {
        let ends = lines.ends.compactMap { Int($0) }
        let start = lines.start.flatMap(Int.init)
        let late = ends.filter(isDropped)
        for id in start.map({ [$0] }) ?? (ends.isEmpty ? printing.map { [$0] } ?? [] : ends) {
            guard let record = records[id], !record.isDropped else { continue }
            runs.add(text, to: &record.call.frames)
        }
        if let start { printing = start }
        defer { if let printing, ends.contains(printing) { self.printing = nil } }
        if let (id, form) = records.first(where: \.value.isForm), !lines.fields.isEmpty || ends.contains(id) {
            let others = Set(ends).subtracting([id]).filter { records[$0]?.ask == nil }.sorted()
            if lines.isMark {
                await close([id], in: run)
            } else {
                await answer(id, form, text, lines, in: run)
            }
            await close(others, in: run)
            return
        }
        if let printing, start == nil, !lines.isMark, let form = records[printing], form.isForm {
            return await run.take(text, lines, of: form.call)
        }
        if let id = ends.first(where: { records[$0]?.ask != nil }), let record = records[id] {
            slowAsks = 0
            if record.isPictured, !lines.isPicture { record.call.pushed = lastPicture }
            await answer(id, record, text, lines, in: run)
        } else if !late.isEmpty {
            late.forEach(remove)
        } else if let printing, start == nil, ends.isEmpty, isDropped(printing) {
            return
        } else if let printing, start == nil, lines.isPicture, let record = records[printing], record.ask != nil {
            await answer(printing, record, text, lines, in: run)
        } else {
            if lines.isPicture {
                if printing == nil {
                    for record in records.values where record.ask?.isAnswer == false { record.isPictured = true }
                }
                lastPicture = lines
            }
            if let record = (printing.map { [$0] } ?? ends).compactMap({ records[$0] }).first(where: \.isAct) {
                await run.take(text, lines, of: record.call)
            } else {
                await run.take(text, lines)
            }
        }
        await close(ends, in: run)
    }

    private func answer(_ id: Int, _ record: Record, _ text: String, _ lines: Frame, in run: SpotRun) async {
        await end(id, record, frame: (text, lines), in: run)
        settle()
    }

    private func close(_ ids: [Int], in run: SpotRun) async {
        for id in ids {
            guard let record = records[id], !record.isDropped else { continue }
            await end(id, record, in: run)
        }
        if !ids.isEmpty { settle() }
    }

    private func end(_ id: Int, _ record: Record, frame: (text: String, lines: Frame)? = nil, in run: SpotRun) async {
        let asks = record.ask?.isAnswer == false
        remove(id)
        if asks { endingAsks += 1 }
        if let frame { await run.take(frame.text, frame.lines, of: record.call) }
        await run.takeEnd(of: record.call, .ended)
        if asks { endingAsks -= 1 }
        run.finish(record.call, .ended)
    }

    private func failed(_ error: Error, telling: Bool = true) {
        guard let run else { return }
        let time = runs.now()
        runs.usage.failedRun(run.spot, failure: StatsLog.Failure(error), at: time)
        failures = failures.filter { time.timeIntervalSince($0) < Self.failureWindow } + [time]
        guard failures.count >= Self.failureLimit else { return telling ? run.fail(error) : () }
        givenUp = .some(stamp)
        let text = "\(run.spot.name) failed \(Self.failureLimit) times in one minute. Openspot will not start it again until its file changes."
        runs.usage.failed(run.spot, fault: text, at: time)
        run.onReport(.failure(text))
    }
}
