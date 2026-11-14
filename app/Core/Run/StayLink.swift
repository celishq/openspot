import Foundation

@MainActor
final class StayLink: ScriptLink {
    private static let failureLimit = 3
    private static let failureWindow: TimeInterval = 60
    private static let slowLimit = 2
    static let droppedLimit = 100

    weak var run: SpotRun?
    let keepsState = true
    private let runs: SpotRuns
    private var script: ScriptProcess?
    private var token: String?
    private var asks: [Int: SpotRun.Ask] = [:] {
        didSet {
            noteReason()
            for id in timers.keys where asks[id] == nil { timers.removeValue(forKey: id)?.cancel() }
        }
    }
    private var timers: [Int: Task<Void, Never>] = [:]
    private var askReason: String?
    private(set) var dropped: Set<Int> = []
    private var droppedBelow = 0
    private(set) var pictured: Set<Int> = []
    private var lastPicture: SpotOutput?
    private var printingCall: Int?
    private var count = 0
    private(set) var sent: [Int: Date] = [:]
    private var calls: [String: ScriptCall] = [:] {
        didSet { noteReason() }
    }
    private var failures: [Date] = []
    private var givenUp: Date??
    private var formAnswer: CheckedContinuation<String?, Error>?
    private var heldScript = false
    private var slowAsks = 0
    private var openCalls: [Int: OpenCall] = [:]

    private struct OpenCall {
        let action: SpotAction
        let input: String?
        let reason: ReadReason?
        let started: Date
        let begin: Date
        var frames: [String] = []
    }

    init(runs: SpotRuns) {
        self.runs = runs
    }

    nonisolated deinit {}

    var isAsking: Bool {
        asks.values.contains { !$0.isAnswer }
    }

    var holdsScript: Bool {
        formAnswer != nil || !calls.isEmpty
    }

    var isReachable: Bool {
        script != nil
    }

    func send(_ call: SpotRun.Call) -> Bool {
        switch call.purpose {
        case .ask(.read(let generation, let reports, _, let tells)):
            guard run?.isWanted == true else { return false }
            guard let script else {
                start(reason: call.reason)
                return self.script != nil
            }
            let id = next()
            ask(.read(generation: generation, reports: reports, tells: tells), id: id, reason: call.variables["OPENSPOT_REASON"])
            opened(id, .read, input: call.input, reason: call.reason)
            script.send(.read, input: call.input, variables: paged(call.variables), id: id)
        case .ask(.search(let query)):
            stop { if case .search = $0 { true } else { false } }
            if let id = send(.read, input: call.input, variables: call.variables, reason: call.reason) { ask(.search(query), id: id, reason: call.variables["OPENSPOT_REASON"]) }
        case .ask(.answer(let text)):
            stop(\.isAnswer)
            if let id = send(call.action, input: call.input, variables: call.variables, reason: call.reason) {
                ask(.answer(text), id: id, reason: call.variables["OPENSPOT_REASON"])
            } else {
                run?.takeAnswers([], to: text)
            }
        case .work:
            send(call.action, input: call.input, key: call.key)
        }
        return script != nil
    }

    func form(_ action: SpotAction, key: String) async throws -> String? {
        guard formAnswer == nil else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            formAnswer = continuation
            send(action, input: nil)
            if script == nil { answerForm(with: .success(nil)) }
        }
    }

    func submit(_ action: SpotAction, key: String, values: String) async throws -> String? {
        send(action, input: values)
        return ""
    }

    func stop(_ call: ScriptCall) {
        guard let id = calls.first(where: { $0.value === call })?.key else { return }
        calls[id] = nil
        if let number = Int(id) {
            drop(number)
            close(number, .stopped)
        }
    }

    func settle() {
        let isNeeded = run?.isWanted == true
        if isNeeded, script == nil { start() }
        if !isNeeded, script != nil { end() }
        guard holdsScript != heldScript else { return }
        heldScript = holdsScript
        runs.updateClock()
    }

    func end() {
        script?.end()
        script = nil
        closeAll(.stopped)
        forgetAsks()
        endCalls(nil)
        answerForm(with: .success(nil))
        run?.scriptEnded()
    }

    func leave() {
        script = nil
        closeAll(.stopped)
        forgetAsks()
        calls = [:]
        answerForm(with: .success(nil))
    }

    func scanned() {
        if let givenUp, fileDate != givenUp {
            self.givenUp = nil
            failures = []
        }
        settle()
    }

    private var startReason: ReadReason {
        guard let run else { return .panel }
        return !run.places.isEmpty ? .sheet : .panel
    }

    private func start(reason: ReadReason? = nil) {
        guard let run, givenUp == nil else { return }
        let (script, frames, token) = runs.stay(run.spot, limit: runs.readLimit)
        self.script = script
        self.token = token
        slowAsks = 0
        let id = next()
        let variables = (reason ?? startReason).variables
        askReason = variables["OPENSPOT_REASON"]
        asks[id] = .read(generation: nil, reports: true)
        opened(id, .read, input: nil, reason: reason ?? startReason)
        script.send(.read, variables: paged(variables), id: id)
        Task { await follow(script, frames) }
    }

    @discardableResult
    private func send(_ action: SpotAction, input: String?, variables: [String: String] = [:], reason: ReadReason? = nil, key: String? = nil) -> Int? {
        if script == nil { start() }
        guard let script else {
            settle()
            return nil
        }
        let id = next()
        opened(id, action, input: input, reason: reason)
        script.send(action, input: input, variables: paged(variables), id: id)
        if let key {
            let call = ScriptCall(action: action, key: key, started: runs.now())
            call.halt = { script.send(text: SpotAction.stopEvent(id: id)) }
            calls[String(id)] = call
            run?.track(call)
        }
        settle()
        return id
    }

    private func paged(_ variables: [String: String]) -> [String: String] {
        run?.withPage(variables) ?? variables
    }

    private func ask(_ ask: SpotRun.Ask, id: Int, reason: String?) {
        askReason = reason
        asks[id] = ask
        guard let script else { return }
        let limit = runs.readLimit
        timers[id] = Task { [weak self, weak script] in
            try? await Task.sleep(for: .seconds(limit))
            guard !Task.isCancelled, let script else { return }
            self?.timeOut(id, of: script)
        }
    }

    private func noteReason() {
        guard let token else { return }
        runs.tokens.setReason(calls.isEmpty && !asks.isEmpty ? askReason : nil, of: token)
    }

    private func timeOut(_ id: Int, of script: ScriptProcess) {
        guard self.script === script, let ask = asks.removeValue(forKey: id) else { return }
        drop(id)
        close(id, .failed(SpotError.timedOut))
        script.send(text: SpotAction.stopEvent(id: id))
        slowAsks += 1
        run?.askFailed(ask, SpotError.timedOut)
        guard slowAsks >= Self.slowLimit else { return }
        end()
        failed(SpotError.timedOut, telling: false)
        settle()
    }

    private func stop(_ kind: (SpotRun.Ask) -> Bool) {
        for (id, ask) in asks {
            guard kind(ask) else { continue }
            asks[id] = nil
            drop(id)
            close(id, .stopped)
            script?.send(text: SpotAction.stopEvent(id: id))
        }
    }

    private func drop(_ id: Int) {
        dropped.insert(id)
        sent[id] = nil
        pictured.remove(id)
        if dropped.count > Self.droppedLimit, let oldest = dropped.min() {
            dropped.remove(oldest)
            droppedBelow = max(droppedBelow, oldest + 1)
        }
    }

    private func isDropped(_ id: Int) -> Bool {
        dropped.contains(id) || (id < droppedBelow && asks[id] == nil && calls[String(id)] == nil)
    }

    private func forgetAsks() {
        for case .answer(let text) in asks.values { run?.takeAnswers([], to: text) }
        sent = [:]
        asks = [:]
        dropped = []
        pictured = []
        printingCall = nil
    }

    private func next() -> Int {
        count += 1
        sent[count] = Date()
        return count
    }

    private func endCalls(_ ids: [String]?) {
        for id in ids ?? Array(calls.keys) {
            guard let call = calls.removeValue(forKey: id) else { continue }
            run?.callEnded(call)
        }
    }

    private func opened(_ id: Int, _ action: SpotAction, input: String?, reason: ReadReason?) {
        openCalls[id] = OpenCall(action: action, input: input, reason: reason, started: runs.now(), begin: Date())
    }

    private func take(_ text: String, _ lines: SpotOutput) {
        let ends = lines.ends.compactMap { Int($0) }
        let owners = lines.start.flatMap(Int.init).map { [$0] } ?? (ends.isEmpty ? printingCall.map { [$0] } ?? [] : ends)
        for id in owners where openCalls[id] != nil { runs.add(text, to: &openCalls[id]!.frames) }
        for id in ends { close(id, .ended) }
    }

    private func close(_ id: Int, _ end: ScriptCall.End, errors: String = "") {
        guard let run, let call = openCalls.removeValue(forKey: id) else { return }
        runs.record(run.spot, call.action, input: call.input, frames: call.frames, errors: errors, end: end, reason: call.reason, started: call.started, begin: call.begin)
    }

    private func closeAll(_ end: ScriptCall.End, errors: String = "") {
        for id in openCalls.keys.sorted() { close(id, end, errors: errors) }
    }

    private func answerForm(with answer: Result<String?, Error>) {
        let waiting = formAnswer
        formAnswer = nil
        waiting?.resume(with: answer)
    }

    private func follow(_ script: ScriptProcess, _ frames: AsyncThrowingStream<String, Error>) async {
        do {
            for try await text in frames {
                let lines = await runs.intake(text, of: run?.spot.id)
                let late = lines.ends.compactMap(Int.init).filter(isDropped)
                if self.script === script {
                    counted(lines.ends)
                    take(text, lines)
                }
                if self.script === script, !lines.ends.isEmpty {
                    endCalls(lines.ends)
                    settle()
                }
                guard self.script === script, let run else {
                    run?.report(toastOf: lines)
                    continue
                }
                if !lines.fields.isEmpty, formAnswer != nil {
                    answerForm(with: .success(text))
                    settle()
                    continue
                }
                let ends = lines.ends.compactMap { Int($0) }
                if let start = lines.start.flatMap(Int.init) { printingCall = start }
                if let printingCall, calls[String(printingCall)] != nil { run.takeMove(lines) }
                defer { if let printingCall, ends.contains(printingCall) { self.printingCall = nil } }
                if let id = ends.first(where: { asks[$0] != nil }), let ask = asks.removeValue(forKey: id) {
                    slowAsks = 0
                    if lines.isPicture || !pictured.contains(id) {
                        await run.takeAnswer(lines, frame: text, to: ask)
                    } else {
                        run.takeEffects(lines, frame: text)
                        await run.takeAnswer(lastPicture?.withoutEffects() ?? lines, frame: text, to: ask)
                    }
                    pictured.remove(id)
                } else if !late.isEmpty {
                    late.forEach { dropped.remove($0) }
                    continue
                } else if let printingCall, lines.start == nil, ends.isEmpty, isDropped(printingCall) {
                    continue
                } else if let printingCall, lines.start == nil, lines.isPicture, let ask = asks.removeValue(forKey: printingCall) {
                    await run.takeAnswer(lines, frame: text, to: ask)
                } else if lines.isPicture {
                    if printingCall == nil { pictured.formUnion(asks.filter { !$0.value.isAnswer }.keys) }
                    lastPicture = lines
                    await run.takePicture(lines, frame: text, of: nil)
                } else {
                    run.takeEffects(lines, frame: text)
                }
            }
        } catch {
            if self.script === script {
                closeAll(.failed(error), errors: script.errors)
                failed(error)
                answerForm(with: .failure(error))
            }
        }
        runs.dropFinished()
        guard self.script === script else { return }
        closeAll(.ended, errors: script.errors)
        self.script = nil
        endCalls(nil)
        forgetAsks()
        run?.lost()
        answerForm(with: .success(""))
    }

    private func counted(_ ends: [String]) {
        guard let run else { return }
        for id in ends.compactMap(Int.init) {
            guard let date = sent.removeValue(forKey: id) else { continue }
            runs.usage.called(run.spot, seconds: Date().timeIntervalSince(date), isFailure: false, at: runs.now())
        }
    }

    private func failed(_ error: Error, telling: Bool = true) {
        guard let run else { return }
        let time = runs.now()
        runs.usage.failedRun(run.spot, at: time)
        failures = failures.filter { time.timeIntervalSince($0) < Self.failureWindow } + [time]
        guard failures.count >= Self.failureLimit else { return telling ? run.fail(error) : () }
        givenUp = .some(fileDate)
        let text = "\(run.spot.name) failed \(Self.failureLimit) times in one minute. Openspot will not start it again until its file changes."
        runs.usage.failed(run.spot, fault: text, at: time)
        run.onReport(.failure(text))
    }

    private var fileDate: Date? {
        guard let run else { return nil }
        return (try? FileManager.default.attributesOfItem(atPath: run.spot.url.path))?[.modificationDate] as? Date
    }
}
