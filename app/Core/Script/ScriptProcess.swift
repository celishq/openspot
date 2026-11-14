import Foundation

public final class ScriptProcess: @unchecked Sendable {
    public enum Mode: Sendable {
        case once(input: String?)
        case stays
    }

    private static let exitPause: TimeInterval = 1
    private static let errorsPause: TimeInterval = 0.5
    private static let forcePause: TimeInterval = 0.1

    private let url: URL
    private let name: String?
    private let arguments: [String]
    private let mode: Mode
    private let limit: TimeInterval?
    private let dataName: String?
    private let careful: CarefulMode?
    private let variables: [String: String]
    private let base: [String: String]?
    private let folder: URL?
    private let stopPause: TimeInterval
    private let input = Pipe()
    private let output = Pipe()
    private let errorOutput = Pipe()
    private let writes = DispatchQueue(label: "openspot.script")
    private let exit = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var continuation: AsyncThrowingStream<String, Error>.Continuation?
    private var hasFrame = false
    private var stopped = false
    private var ended = false
    private var killsLater = false
    private var id: pid_t = 0
    private var waitStatus: Int32?
    private var endTime: ProcessTime?
    private var exitWatch: DispatchSourceProcess?
    private var exitHandlers: [@Sendable (ProcessTime) -> Void] = []
    private var startHandlers: [@Sendable (pid_t) -> Void] = []
    private let errorText: ErrorTail
    private var unended: String?
    private var reader = SheetFrameReader()

    public init(url: URL, name: String? = nil, arguments: [String] = [], mode: Mode = .once(input: nil), limit: TimeInterval? = nil, stopPause: TimeInterval = 2, dataName: String? = nil, variables: [String: String] = [:], errorLimit: Int? = 64 * 1024, careful: Set<SpotUse>? = nil, base: [String: String]? = nil, folder: URL? = nil) {
        self.name = name
        self.base = base
        self.folder = folder
        self.careful = careful.map(CarefulMode.init)
        errorText = ErrorTail(limit: errorLimit)
        self.dataName = dataName
        self.variables = variables
        self.url = url
        self.arguments = arguments
        self.mode = mode
        self.limit = limit
        self.stopPause = stopPause
    }

    public static func environment(base: [String: String], app: String, dataName: String? = nil) -> [String: String] {
        let contents = URL(fileURLWithPath: app).deletingLastPathComponent().deletingLastPathComponent()
        let helpers = contents.appendingPathComponent("Helpers").path
        let config = SpotsFolder.config(environment: base, home: home(of: base))
        let data = dataFolder(base: base, dataName: dataName)
        try? FileManager.default.createDirectory(at: data, withIntermediateDirectories: true)
        var environment = base.merging(["PATH": "\(helpers):\(base["PATH"] ?? "")", "OPENSPOT_DATA": data.path, "OPENSPOT_CONFIG": config.path], uniquingKeysWith: { _, new in new })
        let shell = contents.appendingPathComponent("Resources/openspot.sh").path
        if FileManager.default.fileExists(atPath: shell) { environment["OPENSPOT_SH"] = shell }
        return environment
    }

    static func dataFolder(base: [String: String], dataName: String?) -> URL {
        var data = SpotsFolder.config(environment: base, home: home(of: base)).appendingPathComponent("data", isDirectory: true)
        if let dataName { data.appendPathComponent(URL(fileURLWithPath: dataName).lastPathComponent, isDirectory: true) }
        return data
    }

    private static func home(of base: [String: String]) -> URL {
        base["HOME"].map { URL(fileURLWithPath: $0, isDirectory: true) } ?? FileManager.default.homeDirectoryForCurrentUser
    }

    public static func output(url: URL, arguments: [String] = [], input: String? = nil, limit: TimeInterval? = nil) async throws -> String {
        var text = ""
        for try await frame in ScriptProcess(url: url, arguments: arguments, mode: .once(input: input), limit: limit).start() {
            text += frame
        }
        return text
    }

    public func start() -> AsyncThrowingStream<String, Error> {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: String.self)
        lock.withLock { self.continuation = continuation }
        continuation.onTermination = { [self] reason in
            if case .cancelled = reason, case .once = mode { stop() }
        }
        DispatchQueue.global(qos: .userInitiated).async { [self] in launch() }
        return stream
    }

    private func launch() {
        var text: String?
        var hasInput = true
        if case .once(let given) = mode {
            text = given
            hasInput = given != nil
        }
        let app = Bundle.main.executablePath ?? ""
        let own = Self.environment(base: ProcessInfo.processInfo.environment, app: app, dataName: dataName).merging(variables) { _, new in new }
        let environment = base.map { Self.environment(base: $0, app: app, dataName: dataName).merging(variables) { _, new in new } } ?? own
        let fence = careful?.words(in: own) ?? []
        let errors = errorOutput
        signal(SIGPIPE, SIG_IGN)
        guard !isStopped else {
            lock.withLock { ended = true }
            return abandon()
        }
        let started: pid_t
        do {
            started = try spawn(input: hasInput ? input.fileHandleForReading : nil, output: output.fileHandleForWriting, errors: errors.fileHandleForWriting, environment: environment, fence: fence)
        } catch {
            abandon()
            return finish(throwing: error)
        }
        if hasInput { try? input.fileHandleForReading.close() }
        try? output.fileHandleForWriting.close()
        try? errors.fileHandleForWriting.close()
        TerminalStop.enter(started)
        let (wasStopped, starts) = lock.withLock {
            id = started
            return (stopped, startHandlers)
        }
        starts.forEach { $0(started) }
        watchExit(of: started)
        if wasStopped { stopGroup() }
        if let text { writeAndClose(text) }
        if let limit {
            DispatchQueue.global().asyncAfter(deadline: .now() + limit) { [weak self] in
                guard let self, !lock.withLock({ hasFrame }) else { return }
                stop(because: SpotError.timedOut)
            }
        }
        follow(output: output, errors: errors)
    }

    public func send(_ action: SpotAction, input: String? = nil, variables: [String: String] = [:], id: Int) {
        send(text: action.block(input: input, variables: variables, id: id))
    }

    public func send(text: String) {
        let handle = input.fileHandleForWriting
        writes.async { try? handle.write(contentsOf: Data(text.utf8)) }
    }

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

    public func stop() {
        stop(because: nil)
    }

    public var errors: String {
        errorText.text
    }

    public var failedFrame: String? {
        lock.withLock { unended }
    }

    public var isStopped: Bool {
        lock.withLock { stopped }
    }

    public var isRunning: Bool {
        lock.withLock { id > 0 && waitStatus == nil }
    }

    public var time: ProcessTime {
        let (id, endTime) = lock.withLock { (self.id, self.endTime) }
        if let endTime { return endTime }
        guard id > 0 else { return .zero }
        return ProcessTime(of: id) ?? .zero
    }

    func onStart(_ handler: @escaping @Sendable (pid_t) -> Void) {
        lock.withLock { startHandlers.append(handler) }
    }

    func onExit(_ handler: @escaping @Sendable (ProcessTime) -> Void) {
        lock.withLock { exitHandlers.append(handler) }
    }

    var isLive: Bool {
        !lock.withLock { ended }
    }

    var needsFinish: Bool {
        lock.withLock { !ended || killsLater }
    }

    func leave() {
        if case .stays = mode {
            closeInput()
        } else {
            stop()
        }
    }

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
        let id = lock.withLock { id }
        DispatchQueue.global().asyncAfter(deadline: .now() + stopPause) { [weak self] in
            if id > 0 { kill(-id, SIGKILL) }
            guard let self else { return }
            lock.withLock { killsLater = false }
        }
    }

    private var hasGroup: Bool {
        let id = lock.withLock { self.id }
        return id > 0 && kill(-id, 0) == 0
    }

    private func deliver(_ number: Int32) {
        let id = lock.withLock { self.id }
        if id > 0 { kill(-id, number) }
    }

    private func follow(output: Pipe, errors: Pipe) {
        let errorsRead = DispatchSemaphore(value: 0)
        let lastErrors = LastLine()
        let errorText = errorText
        errors.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                errorsRead.signal()
                return
            }
            lastErrors.take(data)
            errorText.take(data)
        }
        output.fileHandleForReading.readabilityHandler = { [self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return DispatchQueue.global().async { [self] in end(errorsRead: errorsRead, lastErrors: lastErrors) }
            }
            for frame in reader.read(data) { yield(frame) }
            if reader.isOverLimit { stop(because: SpotError.tooLarge) }
        }
    }

    private func end(errorsRead: DispatchSemaphore, lastErrors: LastLine) {
        let hasExited = waitForExit(seconds: Self.exitPause)
        _ = errorsRead.wait(timeout: .now() + Self.errorsPause)
        guard !isStopped else { return lock.withLock { ended = true } }
        if hasExited, exitCode != 0 {
            let line = lastErrors.text
            let last = reader.finish()
            lock.withLock { unended = last }
            let fix = last.flatMap { SpotOutput(text: $0).link }.flatMap(URL.init(string:))
            finish(throwing: fix.map { SpotError.failedWithFix(exitCode, line, $0) } ?? SpotError.failed(exitCode, line))
            return
        }
        if let frame = reader.finish() { yield(frame) }
        finish(throwing: nil)
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

    private var exitCode: Int32 {
        let status = lock.withLock { self.waitStatus } ?? 0
        return status & 0x7f == 0 ? (status >> 8) & 0xff : status & 0x7f
    }

    private func abandon() {
        for handle in [input.fileHandleForReading, output.fileHandleForReading, output.fileHandleForWriting, errorOutput.fileHandleForReading, errorOutput.fileHandleForWriting] {
            try? handle.close()
        }
        closeInput()
        let handlers = lock.withLock {
            endTime = .zero
            defer { exitHandlers = [] }
            return exitHandlers
        }
        handlers.forEach { $0(.zero) }
    }

    private func spawn(input: FileHandle?, output: FileHandle, errors: FileHandle, environment: [String: String], fence wrapper: [String]) throws -> pid_t {
        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        if let input {
            posix_spawn_file_actions_adddup2(&actions, input.fileDescriptor, STDIN_FILENO)
        } else {
            posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0)
        }
        posix_spawn_file_actions_adddup2(&actions, output.fileDescriptor, STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&actions, errors.fileDescriptor, STDERR_FILENO)
        if let folder { posix_spawn_file_actions_addchdir(&actions, folder.path) }
        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_CLOEXEC_DEFAULT))
        posix_spawnattr_setpgroup(&attributes, 0)
        var all = sigset_t()
        sigfillset(&all)
        posix_spawnattr_setsigdefault(&attributes, &all)
        var none = sigset_t()
        sigemptyset(&none)
        posix_spawnattr_setsigmask(&attributes, &none)
        let words = (wrapper.isEmpty ? [name ?? url.path] + arguments : wrapper + [url.path] + arguments).map { strdup($0) } + [nil]
        let pairs = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { (words + pairs).forEach { free($0) } }
        var started: pid_t = 0
        let code = posix_spawn(&started, wrapper.first ?? url.path, &actions, &attributes, words, pairs)
        guard code == 0 else {
            guard code == ENOENT || code == EACCES else { throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO) }
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: url.path, NSURLErrorKey: url])
        }
        return started
    }

    private func watchExit(of started: pid_t) {
        let watch = DispatchSource.makeProcessSource(identifier: started, eventMask: .exit, queue: .global())
        watch.setEventHandler { [self] in reap(started) }
        lock.withLock { exitWatch = watch }
        watch.resume()
        var info = siginfo_t()
        if waitid(P_PID, id_t(started), &info, WEXITED | WNOHANG | WNOWAIT) == 0, info.si_pid == started { reap(started) }
    }

    private func reap(_ started: pid_t) {
        let isFirst = lock.withLock {
            guard let watch = exitWatch else { return false }
            watch.cancel()
            exitWatch = nil
            return true
        }
        guard isFirst else { return }
        let read = ProcessTime(of: started)
        lock.withLock { endTime = read }
        var code: Int32 = 0
        var usage = rusage()
        var result: pid_t = -1
        repeat { result = wait4(started, &code, 0, &usage) } while result == -1 && errno == EINTR
        if result == -1 { code = 1 << 8 }
        let time = read ?? ProcessTime(usage)
        if kill(-started, 0) != 0 { TerminalStop.leave(started) }
        let handlers = lock.withLock {
            waitStatus = code
            endTime = time
            defer { exitHandlers = [] }
            return exitHandlers
        }
        handlers.forEach { $0(time) }
        exit.signal()
    }

    private func waitForExit(seconds: TimeInterval) -> Bool {
        guard exit.wait(timeout: .now() + max(seconds, 0)) == .success else { return false }
        exit.signal()
        return true
    }
}

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
