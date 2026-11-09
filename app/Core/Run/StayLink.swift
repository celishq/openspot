import Foundation

/// The link to a script that stays (05): one process that takes each call as a block on stdin and prints frames at any
/// time. The frame that ends the read or the search that runs is its answer (Y7). It runs while something wants it (Y3), and
/// after 3 failures in one minute it starts again only when its file changes (Y5).
@MainActor
final class StayLink: ScriptLink {
    private static let failureLimit = 3
    private static let failureWindow: TimeInterval = 60

    weak var run: SpotRun?
    let holdsState = true
    private let runs: SpotRuns
    private var script: ScriptProcess?
    /// The call number of the read or the search that the script has not ended yet.
    private var asking: (id: Int, ask: SpotRun.Ask)?
    private var count = 0
    private var calls: [String: ScriptCall] = [:]
    private var failures: [Date] = []
    /// The date of the file when the script failed too often, which keeps it from starting until the file changes.
    private var givenUp: Date??
    private var formAnswer: CheckedContinuation<String?, Error>?

    init(runs: SpotRuns) {
        self.runs = runs
    }

    nonisolated deinit {}

    var isAsking: Bool {
        asking != nil
    }

    var holdsScript: Bool {
        formAnswer != nil || !calls.isEmpty
    }

    var isReachable: Bool {
        script != nil
    }

    /// Sends a read or a search as a block, and a call of work as a block that runs until its `end` (Y7). A read that nothing
    /// wants does not start the script, and a script that does not run gets the read as it starts.
    func send(_ call: SpotRun.Call) {
        switch call.purpose {
        case .ask(.read(let generation, let reports)):
            guard run?.isWanted == true else { return }
            guard let script else { return start(reason: call.reason) }
            let id = next()
            asking = (id, .read(generation: generation, reports: reports))
            script.send(.read, values: call.input, id: id, reason: call.reason)
        case .ask(.search(let query)):
            asking = send(.items(query: query), values: nil, reason: .search).map { ($0, .search(query)) }
        case .work:
            send(call.action, values: call.input, key: call.key)
        }
    }

    /// Sends the call of a form, and waits for the frame with its fields. A second ask leaves the first waiting.
    func form(_ action: SpotAction, key: String) async throws -> String? {
        guard formAnswer == nil else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            formAnswer = continuation
            send(action, values: nil)
            if script == nil { answerForm(with: .success(nil)) }
        }
    }

    func submit(_ action: SpotAction, key: String, values: String) async throws -> String? {
        send(action, values: values)
        return ""
    }

    func stop(_ call: ScriptCall) {
        if let id = calls.first(where: { $0.value === call })?.key { calls[id] = nil }
    }

    func settle() {
        let isNeeded = run?.isWanted == true
        if isNeeded, script == nil { start() }
        if !isNeeded, let script {
            self.script = nil
            script.end()
        }
    }

    func end() {
        script?.end()
        script = nil
        endCalls(nil)
        answerForm(with: .success(nil))
    }

    func leave() {
        script = nil
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

    /// Why a script that starts by itself reads first: its open sheet, `launch` in its `read`, or else the panel.
    private var startReason: ReadReason {
        guard let run else { return .panel }
        return run.isOpen ? .sheet : run.command.read?.has(.launch) == true ? .launch : .panel
    }

    /// Starts the script and asks it for what it shows, with no values. A script that failed too often does not start.
    private func start(reason: ReadReason? = nil) {
        guard let run, givenUp == nil else { return }
        do {
            let (script, frames) = try runs.stay(run.command, limit: runs.readLimit)
            self.script = script
            let id = next()
            asking = (id, .read(generation: nil, reports: true))
            script.send(.read, id: id, reason: reason ?? startReason)
            Task { await follow(script, frames) }
        } catch {
            failed(error)
        }
    }

    /// Sends a call to the script, starts it if it does not run, and returns its number. With nothing that wants it, it ends
    /// after the call. A call with a `key` runs until its own `end`, and a stop sends its number (Y7).
    @discardableResult
    private func send(_ action: SpotAction, values: String?, key: String? = nil, reason: ReadReason? = nil) -> Int? {
        if script == nil { start() }
        guard let script else {
            settle()
            return nil
        }
        let id = next()
        script.send(action, values: values, id: id, reason: reason)
        if let key {
            let call = ScriptCall(action: action, key: key, started: runs.now())
            call.halt = { script.send(text: SpotAction.stopEvent(id: id)) }
            calls[String(id)] = call
            run?.track(call)
        }
        settle()
        return id
    }

    private func next() -> Int {
        count += 1
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

    /// Takes each frame of the script until it ends. A script that Openspot ended shows only its toast.
    private func follow(_ script: ScriptProcess, _ frames: AsyncThrowingStream<String, Error>) async {
        do {
            for try await text in frames {
                let lines = PluginOutput(text: text)
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
                if let asked = asking, lines.ends.contains(String(asked.id)) {
                    asking = nil
                    await run.takeAnswer(lines, frame: text, to: asked.ask)
                } else {
                    await run.takeUpdate(lines, frame: text, from: .call(generation: nil, keeping: nil))
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
        asking = nil
        run?.lost()
        answerForm(with: .success(""))
    }

    /// Counts a failure. It tells the person each one, and the third in one minute stops new starts (Y5).
    private func failed(_ error: Error) {
        guard let run else { return }
        let time = runs.now()
        failures = failures.filter { time.timeIntervalSince($0) < Self.failureWindow } + [time]
        guard failures.count >= Self.failureLimit else { return run.fail(error) }
        givenUp = .some(fileDate)
        run.onReport(.failure("\(run.command.name) failed \(Self.failureLimit) times in one minute. Openspot will not start it again until its file changes."))
    }

    private var fileDate: Date? {
        guard let run else { return nil }
        return (try? FileManager.default.attributesOfItem(atPath: run.command.url.path))?[.modificationDate] as? Date
    }
}
