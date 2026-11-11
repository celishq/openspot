import Foundation

/// The link to a script that stays (05): one process that takes each call as a block on stdin and prints frames at any
/// time. A frame with a block is the whole picture, and the frame that ends the read or the search that runs is its answer
/// (Y7). The frames after `call=<n>` are the output of that call, as the frames of a once script are (Y8). It runs while
/// something wants it (Y3), and after 3 failures in one minute it starts again only when its file changes (Y5).
@MainActor
final class StayLink: ScriptLink {
    private static let failureLimit = 3
    private static let failureWindow: TimeInterval = 60

    weak var run: SpotRun?
    let keepsState = true
    private let runs: SpotRuns
    private var script: ScriptProcess?
    /// Each read and search that the script has not ended yet, by its call number.
    private var asks: [Int: SpotRun.Ask] = [:]
    /// The call numbers of searches and texts of the main search that a newer one stopped, whose late answers change nothing.
    private var dropped: Set<Int> = []
    /// The call numbers of reads and searches that a picture came after, which a frame of only a head then answers.
    private var pictured: Set<Int> = []
    /// The last frame with a block, which answers a read that ends with only a head.
    private var lastPicture: SpotOutput?
    /// The call whose output the script prints now, from the `call=<n>` mark of its start (Y8).
    private var current: Int?
    private var count = 0
    /// When each call that has not ended was sent, by its number.
    private var sent: [Int: Date] = [:]
    private var calls: [String: ScriptCall] = [:]
    private var failures: [Date] = []
    /// The date of the file when the script failed too often, which keeps it from starting until the file changes.
    private var givenUp: Date??
    private var formAnswer: CheckedContinuation<String?, Error>?
    /// Whether the link held the script at the last settle, so that the clock hears when that changes.
    private var heldScript = false

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

    /// Sends a read or a search as a block, and a call of work as a block that runs until its `end` (Y7). A read that nothing
    /// wants does not start the script, and a script that does not run gets the read as it starts.
    func send(_ call: SpotRun.Call) -> Bool {
        switch call.purpose {
        case .ask(.read(let generation, let reports, _)):
            guard run?.isWanted == true else { return false }
            guard let script else {
                start(reason: call.reason)
                return self.script != nil
            }
            let id = next()
            asks[id] = .read(generation: generation, reports: reports)
            script.send(.read, input: call.input, variables: call.variables, id: id)
        case .ask(.search(let query)):
            stop { if case .search = $0 { true } else { false } }
            if let id = send(.items(query: query), input: nil, variables: call.variables) { asks[id] = .search(query) }
        case .ask(.answer(let text)):
            stop(\.isAnswer)
            if let id = send(call.action, input: nil, variables: call.variables) {
                asks[id] = .answer(text)
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
        if let number = Int(id) { dropped.insert(number) }
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
        forgetAsks()
        endCalls(nil)
        answerForm(with: .success(nil))
        run?.scriptEnded()
    }

    func leave() {
        script = nil
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
        let (script, frames) = runs.stay(run.spot, limit: runs.readLimit)
        self.script = script
        let id = next()
        asks[id] = .read(generation: nil, reports: true)
        script.send(.read, variables: (reason ?? startReason).variables, id: id)
        Task { await follow(script, frames) }
    }

    /// Sends a call to the script, starts it if it does not run, and returns its number. With nothing that wants it, it ends
    /// after the call. A call with a `key` runs until its own `end`, and a stop sends its number (Y7).
    @discardableResult
    private func send(_ action: SpotAction, input: String?, variables: [String: String] = [:], key: String? = nil) -> Int? {
        if script == nil { start() }
        guard let script else {
            settle()
            return nil
        }
        let id = next()
        script.send(action, input: input, variables: variables, id: id)
        if let key {
            let call = ScriptCall(action: action, key: key, started: runs.now())
            call.halt = { script.send(text: SpotAction.stopEvent(id: id)) }
            calls[String(id)] = call
            run?.track(call)
        }
        settle()
        return id
    }

    /// Stops each ask of this kind that runs, and drops its answer when it comes (Y7).
    private func stop(_ kind: (SpotRun.Ask) -> Bool) {
        for (id, ask) in asks {
            guard kind(ask) else { continue }
            asks[id] = nil
            dropped.insert(id)
            script?.send(text: SpotAction.stopEvent(id: id))
        }
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
                if self.script === script { counted(lines.ends) }
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
                defer { if let current, ends.contains(current) { self.current = nil } }
                if let id = ends.first(where: { asks[$0] != nil }), let ask = asks.removeValue(forKey: id) {
                    if lines.isPicture || !pictured.contains(id) {
                        await run.takeAnswer(lines, frame: text, to: ask)
                    } else {
                        run.takeEffects(lines, frame: text)
                        await run.takeAnswer(lastPicture?.withoutEffects() ?? lines, frame: text, to: ask)
                    }
                    pictured.remove(id)
                } else if ends.contains(where: { dropped.remove($0) != nil }) {
                    continue
                } else if let current, lines.start == nil, ends.isEmpty, dropped.contains(current) {
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
                failed(error)
                answerForm(with: .failure(error))
            }
        }
        guard self.script === script else { return }
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
            runs.usage.called(run.spot.id, name: run.spot.name, seconds: Date().timeIntervalSince(date))
        }
    }

    /// Counts a failure. It tells the person each one, and the third in one minute stops new starts (Y5).
    private func failed(_ error: Error) {
        guard let run else { return }
        let time = runs.now()
        failures = failures.filter { time.timeIntervalSince($0) < Self.failureWindow } + [time]
        guard failures.count >= Self.failureLimit else { return run.fail(error) }
        givenUp = .some(fileDate)
        let text = "\(run.spot.name) failed \(Self.failureLimit) times in one minute. Openspot will not start it again until its file changes."
        runs.usage.failed(run.spot.id, name: run.spot.name, fault: text)
        run.onReport(.failure(text))
    }

    private var fileDate: Date? {
        guard let run else { return nil }
        return (try? FileManager.default.attributesOfItem(atPath: run.spot.url.path))?[.modificationDate] as? Date
    }
}
