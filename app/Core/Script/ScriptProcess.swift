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
    private let variables: [String: String]
    private let stopPause: TimeInterval
    private let input = Pipe()
    private let writes = DispatchQueue(label: "openspot.script")
    private let exit = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var continuation: AsyncThrowingStream<String, Error>.Continuation?
    private var hasFrame = false
    private var stopped = false
    private var ended = false
    private var killsLater = false
    /// The process ID once it runs, and 0 before.
    private var id: pid_t = 0
    private let errorText: ErrorTail
    private var unended: String?

    /// `limit` is the time the script has to its first frame or its end. With none, it has no limit. `stopPause` is the time
    /// between each step of a stop. `variables` add to its environment. `errorLimit` is how many of the last bytes of stderr
    /// it keeps, and nil keeps all.
    public init(url: URL, arguments: [String] = [], mode: Mode = .once(input: nil), limit: TimeInterval? = nil, stopPause: TimeInterval = 2, dataName: String? = nil, variables: [String: String] = [:], errorLimit: Int? = 64 * 1024) {
        errorText = ErrorTail(limit: errorLimit)
        self.dataName = dataName
        self.variables = variables
        process.executableURL = url
        process.arguments = arguments
        self.mode = mode
        self.limit = limit
        self.stopPause = stopPause
    }

    /// The environment of a script: the `openspot` command of this app on its path, the config folder of the app, the data
    /// folder, which this creates, and the shell helper in the bundle of the app, or what `base` names with no bundle.
    /// `dataName` names a folder of its own inside the data of the app.
    public static func environment(base: [String: String], app: String, dataName: String? = nil) -> [String: String] {
        let contents = URL(fileURLWithPath: app).deletingLastPathComponent().deletingLastPathComponent()
        let helpers = contents.appendingPathComponent("Helpers").path
        let home = base["HOME"].map { URL(fileURLWithPath: $0, isDirectory: true) } ?? FileManager.default.homeDirectoryForCurrentUser
        let config = PluginFolder.config(environment: base, home: home)
        var data = config.appendingPathComponent("data", isDirectory: true)
        if let dataName { data.appendPathComponent(URL(fileURLWithPath: dataName).lastPathComponent, isDirectory: true) }
        try? FileManager.default.createDirectory(at: data, withIntermediateDirectories: true)
        var environment = base.merging(["PATH": "\(helpers):\(base["PATH"] ?? "")", "OPENSPOT_DATA": data.path, "OPENSPOT_CONFIG": config.path], uniquingKeysWith: { _, new in new })
        let shell = contents.appendingPathComponent("Resources/openspot.sh").path
        if FileManager.default.fileExists(atPath: shell) { environment["OPENSPOT_SH"] = shell }
        return environment
    }

    /// Runs a process once, and returns all that it prints.
    public static func output(url: URL, arguments: [String] = [], input: String? = nil, limit: TimeInterval? = nil) async throws -> String {
        var text = ""
        for try await frame in ScriptProcess(url: url, arguments: arguments, mode: .once(input: input), limit: limit).start() {
            text += frame
        }
        return text
    }

    /// Starts the process on another thread, and returns its frames at once. A line `---` ends a frame, and so does the end
    /// of the output. A script that cannot start ends its frames with the reason. Ending the stream early stops a process
    /// that runs once.
    public func start() -> AsyncThrowingStream<String, Error> {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: String.self)
        lock.withLock { self.continuation = continuation }
        continuation.onTermination = { [self] reason in
            if case .cancelled = reason, case .once = mode { stop() }
        }
        DispatchQueue.global(qos: .userInitiated).async { [self] in launch() }
        return stream
    }

    /// Runs the process, unless a stop came first, and follows its output. A stop that comes while it starts reaches it.
    private func launch() {
        var text: String?
        switch mode {
        case .stays:
            process.standardInput = input
        case .once(let given):
            text = given
            process.standardInput = given == nil ? FileHandle.nullDevice : input
        }
        process.environment = Self.environment(base: ProcessInfo.processInfo.environment, app: Bundle.main.executablePath ?? "", dataName: dataName).merging(variables) { _, new in new }
        let output = Pipe()
        process.standardOutput = output
        let errors = Pipe()
        process.standardError = errors
        let exit = exit
        process.terminationHandler = { _ in exit.signal() }
        signal(SIGPIPE, SIG_IGN)
        guard !isStopped else { return lock.withLock { ended = true } }
        do {
            try process.run()
        } catch {
            return finish(throwing: error)
        }
        let wasStopped = lock.withLock {
            id = process.processIdentifier
            return stopped
        }
        if wasStopped { stopGroup() }
        if let text { writeAndClose(text) }
        if let limit {
            DispatchQueue.global().asyncAfter(deadline: .now() + limit) { [self] in
                if !lock.withLock({ hasFrame }) { stop(because: PluginError.timedOut) }
            }
        }
        follow(output: output, errors: errors)
    }

    /// Sends one call to the script as a block, with its `id`, the `reason` of a read and the values of its sheet, in the
    /// order of the calls.
    public func send(_ action: SpotAction, values: String? = nil, id: Int, reason: ReadReason? = nil) {
        send(text: action.event(values: values, id: id, reason: reason))
    }

    /// Sends a block as it is, in the order of the calls.
    public func send(text: String) {
        let handle = input.fileHandleForWriting
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

    /// What the process printed on stderr, all of it or its last bytes up to `errorLimit`, once its output has closed.
    public var errors: String {
        errorText.text
    }

    /// The last frame of a call that failed, which had no `---` after it. The app does not draw it.
    public var failedFrame: String? {
        lock.withLock { unended }
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

    /// Whether a quit must wait for it: its call runs, or a stop will still kill what its group holds.
    var needsFinish: Bool {
        lock.withLock { !ended || killsLater }
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
        lock.withLock { killsLater = true }
        deliver(SIGTERM)
        DispatchQueue.global().asyncAfter(deadline: .now() + stopPause) { [self] in
            deliver(SIGKILL)
            lock.withLock { killsLater = false }
        }
    }

    /// Whether a process of its group still runs.
    private var hasGroup: Bool {
        let id = lock.withLock { id }
        return id > 0 && kill(-id, 0) == 0
    }

    /// Sends a signal to the process group of the script, which holds the children it started.
    private func deliver(_ number: Int32) {
        let id = lock.withLock { id }
        if id > 0 { kill(-id, number) }
    }

    private func follow(output: Pipe, errors: Pipe) {
        let errorsRead = DispatchSemaphore(value: 0)
        let lastErrors = LastLine()
        let errorText = errorText
        DispatchQueue.global().async {
            while let data = Self.next(errors) {
                lastErrors.take(data)
                errorText.take(data)
            }
            errorsRead.signal()
        }
        DispatchQueue.global().async { [self] in
            var reader = SheetFrameReader()
            while let data = Self.next(output) {
                for frame in reader.read(data) { yield(frame) }
            }
            let hasExited = waitForExit(seconds: Self.exitPause)
            _ = errorsRead.wait(timeout: .now() + Self.errorsPause)
            guard !isStopped else { return lock.withLock { ended = true } }
            if hasExited, process.terminationStatus != 0 {
                let line = lastErrors.text
                let last = reader.finish()
                lock.withLock { unended = last }
                let fix = last.flatMap { PluginOutput(text: $0).link }.flatMap(URL.init(string:))
                finish(throwing: fix.map { PluginError.failedWithFix(process.terminationStatus, line, $0) } ?? PluginError.failed(process.terminationStatus, line))
                return
            }
            if let frame = reader.finish() { yield(frame) }
            finish(throwing: nil)
        }
    }

    /// The next bytes of a pipe, or nil at its end. Each read frees its own buffer, so a long read keeps none of the last.
    private static func next(_ pipe: Pipe) -> Data? {
        autoreleasepool {
            let data = pipe.fileHandleForReading.availableData
            return data.isEmpty ? nil : data
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

/// The last line that has words of a stream that one queue writes and another reads. It keeps no more than that line and
/// one line break after it, and no more than the end of a line longer than its limit, cut between two characters.
private final class LastLine: @unchecked Sendable {
    private static let limit = 16 * 1024
    private static let breaks: Set<UInt8> = [UInt8(ascii: "\n"), UInt8(ascii: "\r")]

    private let lock = NSLock()
    private var bytes = Data()

    func take(_ data: Data) {
        lock.withLock {
            bytes.append(data)
            guard let end = bytes.lastIndex(where: { !Self.breaks.contains($0) }) else { return bytes.removeAll() }
            let start = bytes[..<end].lastIndex(of: UInt8(ascii: "\n")).map { $0 + 1 } ?? bytes.startIndex
            var cut = max(start, end + 1 - Self.limit)
            while cut < end, bytes[cut] & 0xC0 == 0x80 { cut += 1 }
            bytes = Data(bytes[cut..<min(end + 2, bytes.endIndex)])
        }
    }

    var text: String {
        lock.withLock { String(decoding: bytes, as: UTF8.self).split(whereSeparator: \.isNewline).last.map(String.init) ?? "" }
    }
}

/// The end of a stream that one queue writes and another reads: all of it, or its last bytes up to a limit, cut between two
/// characters, so that a script that writes to stderr all day holds no more than twice that.
private final class ErrorTail: @unchecked Sendable {
    private let limit: Int?
    private let lock = NSLock()
    private var bytes = Data()

    init(limit: Int?) {
        self.limit = limit
    }

    func take(_ data: Data) {
        lock.withLock {
            bytes.append(data)
            guard let limit, bytes.count > 2 * limit else { return }
            var cut = bytes.endIndex - limit
            while cut < bytes.endIndex, bytes[cut] & 0xC0 == 0x80 { cut += 1 }
            bytes = Data(bytes[cut...])
        }
    }

    var text: String {
        lock.withLock { String(decoding: bytes, as: UTF8.self) }
    }
}
