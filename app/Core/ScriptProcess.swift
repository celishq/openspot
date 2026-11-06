import Foundation

/// One process of a script, and the only way to start one. `once` gives it one input, and `stays` keeps its input open
/// for calls. Both give frames as the script prints them, and end when its output closes.
public final class ScriptProcess: @unchecked Sendable {
    public enum Mode: Sendable {
        case once(input: String?)
        case stays
    }

    private static let exitPause: TimeInterval = 1
    private static let errorsPause: TimeInterval = 0.5
    private static let forcePause: TimeInterval = 0.1

    private let process = Process()
    private let mode: Mode
    private let limit: TimeInterval?
    private let dataName: String?
    private let stopPause: TimeInterval
    private let input = Pipe()
    private let writes = DispatchQueue(label: "openspot.script")
    private let exit = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var continuation: AsyncThrowingStream<String, Error>.Continuation?
    private var hasFrame = false
    private var stopped = false
    private var ended = false

    /// `limit` is the time the script has to its first frame or its end. With none, it has no limit. `stopPause` is the time
    /// between each step of a stop.
    public init(url: URL, arguments: [String] = [], mode: Mode = .once(input: nil), limit: TimeInterval? = nil, stopPause: TimeInterval = 2, dataName: String? = nil) {
        self.dataName = dataName
        process.executableURL = url
        process.arguments = arguments
        self.mode = mode
        self.limit = limit
        self.stopPause = stopPause
    }

    /// The environment of a script: the `openspot` command of this app on its path, the data folder, which this creates, and
    /// the shell helper in the bundle of the app. With no bundle, as in a test, the helper is what `base` names. `dataName`
    /// names a folder of its own inside the data of the app.
    public static func environment(base: [String: String], app: String, stays: Bool = false, dataName: String? = nil) -> [String: String] {
        let contents = URL(fileURLWithPath: app).deletingLastPathComponent().deletingLastPathComponent()
        let helpers = contents.appendingPathComponent("Helpers").path
        let home = base["HOME"].map { URL(fileURLWithPath: $0, isDirectory: true) } ?? FileManager.default.homeDirectoryForCurrentUser
        var data = PluginFolder.config(environment: base, home: home).appendingPathComponent("data", isDirectory: true)
        if let dataName { data.appendPathComponent(URL(fileURLWithPath: dataName).lastPathComponent, isDirectory: true) }
        try? FileManager.default.createDirectory(at: data, withIntermediateDirectories: true)
        var environment = base.merging(["PATH": "\(helpers):\(base["PATH"] ?? "")", "OPENSPOT_DATA": data.path], uniquingKeysWith: { _, new in new })
        let shell = contents.appendingPathComponent("Resources/openspot.sh").path
        if FileManager.default.fileExists(atPath: shell) { environment["OPENSPOT_SH"] = shell }
        environment["OPENSPOT_STAYS"] = stays ? "true" : nil
        return environment
    }

    /// Runs a process once, and returns all that it prints.
    public static func output(url: URL, arguments: [String] = [], input: String? = nil, limit: TimeInterval? = nil) async throws -> String {
        var text = ""
        for try await frame in try ScriptProcess(url: url, arguments: arguments, mode: .once(input: input), limit: limit).start() {
            text += frame
        }
        return text
    }

    /// Starts the process, and returns its frames. A line `---` ends a frame, and so does the end of the output. Ending the
    /// stream early stops a process that runs once.
    public func start() throws -> AsyncThrowingStream<String, Error> {
        var text: String?
        var stays = false
        switch mode {
        case .stays:
            stays = true
            process.standardInput = input
        case .once(let given):
            text = given
            process.standardInput = given == nil ? FileHandle.nullDevice : input
        }
        process.environment = Self.environment(base: ProcessInfo.processInfo.environment, app: Bundle.main.executablePath ?? "", stays: stays, dataName: dataName)
        let output = Pipe()
        process.standardOutput = output
        let errors = Pipe()
        process.standardError = errors
        let exit = exit
        process.terminationHandler = { _ in exit.signal() }
        signal(SIGPIPE, SIG_IGN)
        try process.run()
        if let text { writeAndClose(text) }
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: String.self)
        lock.withLock { self.continuation = continuation }
        continuation.onTermination = { [self] reason in
            if case .cancelled = reason, case .once = mode { stop() }
        }
        if let limit {
            DispatchQueue.global().asyncAfter(deadline: .now() + limit) { [self] in
                if !lock.withLock({ hasFrame }) { stop(because: PluginError.timedOut) }
            }
        }
        follow(output: output, errors: errors)
        return stream
    }

    /// Sends one call to the script as a block, with the values of its sheet, in the order of the calls.
    public func send(_ action: SpotAction, values: String? = nil) {
        let handle = input.fileHandleForWriting
        let text = action.event(values: values)
        writes.async { try? handle.write(contentsOf: Data(text.utf8)) }
    }

    /// Closes its input after the calls already sent, which ends a script that reads to the end. After 2 seconds its group
    /// gets the terminate signal, and 2 seconds later Openspot kills what still runs.
    public func end() {
        closeInput()
        DispatchQueue.global().asyncAfter(deadline: .now() + stopPause) { [self] in
            if lock.withLock({ ended && !stopped }) {
                stopGroup()
            } else {
                stop()
            }
        }
    }

    /// Stops the call: its stream ends now with no error, and each process in its group gets the terminate signal. After 2
    /// seconds, Openspot kills what still runs. A call that ended by itself has nothing to stop.
    public func stop() {
        stop(because: nil)
    }

    /// Whether `stop` or the time limit ended this process. Its silence then says nothing.
    public var isStopped: Bool {
        lock.withLock { stopped }
    }

    public var isRunning: Bool {
        process.isRunning
    }

    /// Whether its output is still open, so that the call has not ended.
    var isLive: Bool {
        !lock.withLock { ended }
    }

    /// Asks the process to end as quitting does: a staying script's input closes, and any other process stops.
    func leave() {
        if case .stays = mode {
            closeInput()
        } else {
            stop()
        }
    }

    /// Waits for the end of each process in its group, up to the time given. Ends what still runs by force after that.
    func finish(by deadline: Date) {
        _ = waitForExit(seconds: deadline.timeIntervalSinceNow)
        while hasGroup, Date() < deadline { Thread.sleep(forTimeInterval: Self.forcePause) }
        guard hasGroup else { return }
        deliver(SIGTERM)
        Thread.sleep(forTimeInterval: Self.forcePause)
        deliver(SIGKILL)
    }

    private func closeInput() {
        let handle = input.fileHandleForWriting
        writes.async { try? handle.close() }
    }

    private func writeAndClose(_ text: String) {
        let handle = input.fileHandleForWriting
        DispatchQueue.global().async {
            try? handle.write(contentsOf: Data(text.utf8))
            try? handle.close()
        }
    }

    private func stop(because error: Error?) {
        let continuation: AsyncThrowingStream<String, Error>.Continuation? = lock.withLock {
            guard !stopped, !ended else { return nil }
            stopped = true
            return self.continuation
        }
        guard let continuation else { return }
        stopGroup()
        continuation.finish(throwing: error)
    }

    private func stopGroup() {
        deliver(SIGTERM)
        DispatchQueue.global().asyncAfter(deadline: .now() + stopPause) { [self] in deliver(SIGKILL) }
    }

    /// Whether a process of its group still runs.
    private var hasGroup: Bool {
        let id = process.processIdentifier
        return id > 0 && kill(-id, 0) == 0
    }

    /// Sends a signal to the process group of the script, which holds the children it started.
    private func deliver(_ number: Int32) {
        let id = process.processIdentifier
        if id > 0 { kill(-id, number) }
    }

    private func follow(output: Pipe, errors: Pipe) {
        let errorsRead = DispatchSemaphore(value: 0)
        let lastErrors = ScriptText()
        DispatchQueue.global().async {
            lastErrors.text = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            errorsRead.signal()
        }
        DispatchQueue.global().async { [self] in
            var reader = SheetFrameReader()
            while true {
                let data = output.fileHandleForReading.availableData
                if data.isEmpty { break }
                for frame in reader.read(data) { yield(frame) }
            }
            let hasExited = waitForExit(seconds: Self.exitPause)
            _ = errorsRead.wait(timeout: .now() + Self.errorsPause)
            guard !isStopped else { return lock.withLock { ended = true } }
            if hasExited, process.terminationStatus != 0 {
                let line = lastErrors.text.split(separator: "\n").last.map(String.init) ?? ""
                finish(throwing: PluginError.failed(process.terminationStatus, line))
                return
            }
            if let frame = reader.finish() { yield(frame) }
            finish(throwing: nil)
        }
    }

    private func yield(_ frame: String) {
        let continuation: AsyncThrowingStream<String, Error>.Continuation? = lock.withLock {
            guard !stopped else { return nil }
            hasFrame = true
            return self.continuation
        }
        continuation?.yield(frame)
    }

    private func finish(throwing error: Error?) {
        let continuation: AsyncThrowingStream<String, Error>.Continuation? = lock.withLock {
            ended = true
            hasFrame = true
            return self.continuation
        }
        continuation?.finish(throwing: error)
    }

    /// Waits for the termination handler to signal, and leaves the signal for the next one that waits.
    private func waitForExit(seconds: TimeInterval) -> Bool {
        guard exit.wait(timeout: .now() + max(seconds, 0)) == .success else { return false }
        exit.signal()
        return true
    }
}

/// Text that one queue writes and another reads.
private final class ScriptText: @unchecked Sendable {
    private let lock = NSLock()
    private var value = ""

    var text: String {
        get { lock.withLock { value } }
        set { lock.withLock { value = newValue } }
    }
}
