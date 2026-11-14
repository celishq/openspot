import Foundation

/// The link to a script that stays: one process that takes each call as a block on stdin and prints frames at any
/// time. A frame with a block is the whole picture, and the frame that ends the read or the search that runs is its answer
/// (protocol: Modes). The frames after `call=<n>` are the output of that call, as the frames of a once script are (protocol: Modes). It runs while
/// something wants it (protocol: Modes), and after 3 failures in one minute it starts again only when its file changes (protocol: Modes). A read or a
/// search after the first that the script does not end within the read limit stops, fails as a slow read, and its late
/// answer changes nothing; a second such stop with no answer in time between starts the script again, as a failure.
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
    /// The token of the script that runs, whose reason tells the API whether the script reads now (protocol: Trust).
    private var token: String?
    /// Each read and search that the script has not ended yet, by its call number.
    private var asks: [Int: SpotRun.Ask] = [:] {
        didSet {
            noteReason()
            for id in timers.keys where asks[id] == nil { timers.removeValue(forKey: id)?.cancel() }
        }
    }
    /// The timer of each ask that waits, which a frame that ends the ask cancels.
    private var timers: [Int: Task<Void, Never>] = [:]
    /// The reason of the newest read or search that was sent.
    private var askReason: String?
    /// The call numbers of searches and texts of the main search that a newer one stopped, whose late answers change nothing.
    private(set) var dropped: Set<Int> = []
    /// Each call below this number that neither waits nor runs was dropped, though `dropped` let go of it to keep its limit.
    private var droppedBelow = 0
    /// The call numbers of reads and searches that a picture came after, which a frame of only a head then answers.
    private(set) var pictured: Set<Int> = []
    /// The last frame with a block, which answers a read that ends with only a head.
    private var lastPicture: SpotOutput?
    /// The call whose output the script prints now, from the `call=<n>` mark of its start (protocol: Modes).
    private var current: Int?
    private var count = 0
    /// When each call that has not ended was sent, by its number.
    private(set) var sent: [Int: Date] = [:]
    private var calls: [String: ScriptCall] = [:] {
        didSet { noteReason() }
    }
    private var failures: [Date] = []
    /// The date of the file when the script failed too often, which keeps it from starting until the file changes.
    private var givenUp: Date??
    private var formAnswer: CheckedContinuation<String?, Error>?
    /// Whether the link held the script at the last settle, so that the clock hears when that changes.
    private var heldScript = false
    /// The asks of the script that runs which its read limit stopped.
    private var slowAsks = 0
    /// Each call that has not ended yet, by its number, with the frames that answered it so far.
    private var open: [Int: OpenCall] = [:]

    /// A call that the runs record once it ends.
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

    /// Sends a read or a search as a block, and a call of work as a block that runs until its `end` (protocol: Modes). A read that nothing
    /// wants does not start the script, and a script that does not run gets the read as it starts.
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

    /// Sends the call of a form, and waits for the frame with its fields. A second ask leaves the first waiting.
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

    /// Forgets a call that a person stopped, whose later frames change nothing.
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

    /// Why a script that starts by itself reads first: its open sheet, or else the panel.
    private var startReason: ReadReason {
        guard let run else { return .panel }
        return !run.places.isEmpty ? .sheet : .panel
    }

    /// Starts the script and asks it for what it shows, with no values. A script that failed too often does not start.
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

    /// Sends a call to the script, starts it if it does not run, and returns its number. With nothing that wants it, it ends
    /// after the call. A call with a `key` runs until its own `end`, and a stop sends its number (protocol: Modes).
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

    /// The variables of a call with the page of the sheet added.
    private func paged(_ variables: [String: String]) -> [String: String] {
        run?.withPage(variables) ?? variables
    }

    /// Keeps an ask until the frame that ends it, for the read limit at most.
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

    /// Tells the API the reason of the script's call: that of the newest ask while one waits and no call of work runs, and
    /// none else, so that a call of `openspot` from the script is refused in a read whatever its variables say.
    private func noteReason() {
        guard let token else { return }
        runs.tokens.setReason(calls.isEmpty && !asks.isEmpty ? askReason : nil, of: token)
    }

    /// Stops an ask that the script did not end in time, which fails as a slow read. The second one starts the script
    /// again.
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

    /// Stops each ask of this kind that runs, and drops its answer when it comes (protocol: Modes).
    private func stop(_ kind: (SpotRun.Ask) -> Bool) {
        for (id, ask) in asks {
            guard kind(ask) else { continue }
            asks[id] = nil
            drop(id)
            close(id, .stopped)
            script?.send(text: SpotAction.stopEvent(id: id))
        }
    }

    /// Forgets a call that a stop or a time-out ended, whose late answer changes nothing. It keeps the newest
    /// `droppedLimit` such calls.
    private func drop(_ id: Int) {
        dropped.insert(id)
        sent[id] = nil
        pictured.remove(id)
        if dropped.count > Self.droppedLimit, let oldest = dropped.min() {
            dropped.remove(oldest)
            droppedBelow = max(droppedBelow, oldest + 1)
        }
    }

    /// Whether a stop or a time-out dropped this call, so that its late frames change nothing.
    private func isDropped(_ id: Int) -> Bool {
        dropped.contains(id) || (id < droppedBelow && asks[id] == nil && calls[String(id)] == nil)
    }

    /// Drops each ask, and ends each text of the main search with no rows, so that nothing waits for it.
    private func forgetAsks() {
        for case .answer(let text) in asks.values { run?.takeAnswers([], to: text) }
        sent = [:]
        asks = [:]
        dropped = []
        pictured = []
        current = nil
    }

    private func next() -> Int {
        count += 1
        sent[count] = Date()
        return count
    }

    /// Ends the calls that a frame names, or each call when `ids` is nil.
    private func endCalls(_ ids: [String]?) {
        for id in ids ?? Array(calls.keys) {
            guard let call = calls.removeValue(forKey: id) else { continue }
            run?.callEnded(call)
        }
    }

    /// Keeps a call that was sent until it ends.
    private func opened(_ id: Int, _ action: SpotAction, input: String?, reason: ReadReason?) {
        open[id] = OpenCall(action: action, input: input, reason: reason, started: runs.now(), begin: Date())
    }

    /// Adds a frame to the call that printed it: the call that its `call=<n>` starts, else each call that it ends, else the
    /// call that prints now. Then it records each call that the frame ends.
    private func take(_ text: String, _ lines: SpotOutput) {
        let ends = lines.ends.compactMap { Int($0) }
        let owners = lines.start.flatMap(Int.init).map { [$0] } ?? (ends.isEmpty ? current.map { [$0] } ?? [] : ends)
        for id in owners where open[id] != nil { runs.add(text, to: &open[id]!.frames) }
        for id in ends { close(id, .ended) }
    }

    /// Records a call that ended, once.
    private func close(_ id: Int, _ end: ScriptCall.End, errors: String = "") {
        guard let run, let call = open.removeValue(forKey: id) else { return }
        runs.record(run.spot, call.action, input: call.input, frames: call.frames, errors: errors, end: end, reason: call.reason, started: call.started, begin: call.begin)
    }

    /// Records each call that has not ended, in the order they were sent.
    private func closeAll(_ end: ScriptCall.End, errors: String = "") {
        for id in open.keys.sorted() { close(id, end, errors: errors) }
    }

    private func answerForm(with answer: Result<String?, Error>) {
        let waiting = formAnswer
        formAnswer = nil
        waiting?.resume(with: answer)
    }

    /// Takes each frame of the script until it ends, each after the open motion of its sheet. A script that Openspot ended
    /// shows only its toast.
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
                if let start = lines.start.flatMap(Int.init) { current = start }
                if let current, calls[String(current)] != nil { run.takeMove(lines) }
                defer { if let current, ends.contains(current) { self.current = nil } }
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
                } else if let current, lines.start == nil, ends.isEmpty, isDropped(current) {
                    continue
                } else if let current, lines.start == nil, lines.isPicture, let ask = asks.removeValue(forKey: current) {
                    await run.takeAnswer(lines, frame: text, to: ask)
                } else if lines.isPicture {
                    if current == nil { pictured.formUnion(asks.filter { !$0.value.isAnswer }.keys) }
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

    /// Counts each call that a frame ends, with the time since it was sent.
    private func counted(_ ends: [String]) {
        guard let run else { return }
        for id in ends.compactMap(Int.init) {
            guard let date = sent.removeValue(forKey: id) else { continue }
            runs.usage.called(run.spot, seconds: Date().timeIntervalSince(date), isFailure: false, at: runs.now())
        }
    }

    /// Counts a failure. It tells the person each one that `telling` allows, and the third in one minute stops new starts
    /// (protocol: Modes).
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
