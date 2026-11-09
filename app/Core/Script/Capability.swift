import Foundation

/// A capability with state, which it keeps in a helper process. The first call starts the helper, each call reaches it over
/// a local socket, and it exits after its idle time with no call. A lock that the system frees at any exit keeps it to one.
/// The helper is the same program, started with the arguments `helper <name>`, in its own process group.
public struct Capability: Sendable {
    public enum Failure: LocalizedError, Equatable {
        case notStarted(name: String, cause: String, fix: String)
        case noAnswer(name: String)

        public var errorDescription: String? {
            switch self {
            case .notStarted(let name, let cause, let fix): "openspot could not start its \(name) helper: \(cause). \(fix)"
            case .noAnswer(let name): "The \(name) helper of openspot ended before it answered. Run the call again."
            }
        }
    }

    private static let startLimit: TimeInterval = 10
    private static let retryPause: TimeInterval = 0.01
    private static let queueLength: Int32 = 64
    /// The seconds that the helper waits for one stalled caller, so that the caller does not stop every other call.
    private static let callerLimit = 5

    public let name: String
    private let folder: URL
    private let idle: TimeInterval

    public init(name: String, folder: URL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true), idle: TimeInterval = 30) {
        self.name = name
        self.folder = folder
        self.idle = idle
    }

    private var socketPath: String { folder.appendingPathComponent("openspot-\(name).socket").path }
    private var lockPath: String { folder.appendingPathComponent("openspot-\(name).lock").path }
    private var folderFix: String { "Make sure that you can write to \(folder.path), then run the call again." }

    /// Sends one request to the helper, and starts the helper if it does not run. An answer can be empty, and a helper that
    /// ends first is a failure, so silence never counts as an answer.
    public func call(_ request: Data) throws -> Data {
        signal(SIGPIPE, SIG_IGN)
        let connection = try reach()
        defer { connection.close() }
        guard connection.send(request), let answer = connection.receive() else { throw Failure.noAnswer(name: name) }
        return answer
    }

    /// Runs as the helper: answers one call at a time until the idle time passes with no call and no work, such as a
    /// recording. It exits at once when another helper holds the lock, and with a line on stderr and code 1 when it cannot listen.
    /// `runMain` keeps the main thread, such as the event loop of an app that a framework needs.
    public func serve(
        isBusy: @escaping @Sendable () async -> Bool = { false },
        runMain: () -> Never = dispatchMain,
        _ answer: @escaping @Sendable (Data) async -> Data
    ) -> Never {
        signal(SIGPIPE, SIG_IGN)
        signal(SIGHUP, SIG_IGN)
        let listener = listen()
        let empty = open("/dev/null", O_WRONLY)
        if empty >= 0 { dup2(empty, STDERR_FILENO) }
        Task.detached {
            while true {
                if Self.isReady(listener, seconds: idle) {
                    await Self.answerNext(on: listener, with: answer)
                } else if await !isBusy() {
                    break
                }
            }
            unlink(socketPath)
            while Self.isReady(listener, seconds: 0) {
                await Self.answerNext(on: listener, with: answer)
            }
            exit(0)
        }
        runMain()
    }

    /// A connection to the helper. The helper shows that it runs by taking the connection. A helper that lost the race to
    /// another one exits with code 0, and any other exit is a failed start.
    private func reach() throws -> Connection {
        guard Connection.address(of: socketPath) != nil else {
            throw Failure.notStarted(name: name, cause: "the path \(socketPath) is too long for a socket", fix: "Use a shorter folder.")
        }
        let deadline = Date().addingTimeInterval(Self.startLimit)
        let ended = DispatchSemaphore(value: 0)
        var helper: (process: Process, errors: Pipe)?
        while Date() < deadline {
            if let connection = Connection(path: socketPath) { return connection }
            guard let running = helper else {
                helper = try start(signalling: ended)
                continue
            }
            guard ended.wait(timeout: .now() + Self.retryPause) == .success else { continue }
            guard running.process.terminationStatus == 0 else { throw failedStart(of: running.process, errors: running.errors) }
            helper = nil
            Thread.sleep(forTimeInterval: Self.retryPause)
        }
        throw Failure.notStarted(name: name, cause: "it did not answer in \(Int(Self.startLimit)) seconds", fix: "Run the call again.")
    }

    private func start(signalling ended: DispatchSemaphore) throws -> (process: Process, errors: Pipe) {
        let process = Process()
        let errors = Pipe()
        process.executableURL = Bundle.main.executableURL
        process.arguments = ["helper", name]
        process.currentDirectoryURL = URL(fileURLWithPath: "/")
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errors
        process.terminationHandler = { _ in ended.signal() }
        do {
            try process.run()
        } catch {
            throw Failure.notStarted(name: name, cause: error.localizedDescription, fix: "Open the command from the Openspot app that you installed.")
        }
        return (process, errors)
    }

    private func failedStart(of process: Process, errors: Pipe) -> Failure {
        let said = String(decoding: errors.fileHandleForReading.availableData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return .notStarted(name: name, cause: said.isEmpty ? "it exited with code \(process.terminationStatus)" : said, fix: folderFix)
    }

    /// Takes the lock and listens, and returns the socket. A helper that crashed leaves a socket file and no lock, so the
    /// file goes first.
    private func listen() -> Int32 {
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            quit("cannot create \(folder.path): \(error.localizedDescription)")
        }
        umask(0o077)
        let lock = open(lockPath, O_CREAT | O_RDWR | O_CLOEXEC, 0o600)
        guard lock >= 0 else {
            let cause = String(cString: strerror(errno))
            quit("cannot open \(lockPath): \(cause)")
        }
        guard flock(lock, LOCK_EX | LOCK_NB) == 0 else { exit(0) }
        unlink(socketPath)
        guard let address = Connection.address(of: socketPath) else { quit("the path \(socketPath) is too long for a socket") }
        let listener = socket(AF_UNIX, SOCK_STREAM, 0)
        let bound = withUnsafePointer(to: address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(listener, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard listener >= 0, bound == 0, Darwin.listen(listener, Self.queueLength) == 0 else {
            let cause = String(cString: strerror(errno))
            quit("cannot listen on \(socketPath): \(cause)")
        }
        return listener
    }

    private func quit(_ message: String) -> Never {
        FileHandle.standardError.write(Data("\(message)\n".utf8))
        exit(1)
    }

    /// Waits for a call on the socket, and returns false when the time passes with none.
    private static func isReady(_ listener: Int32, seconds: TimeInterval) -> Bool {
        var request = pollfd(fd: listener, events: Int16(POLLIN), revents: 0)
        while true {
            let count = poll(&request, 1, Int32(seconds * 1000))
            if count >= 0 { return count > 0 }
            if errno != EINTR { return false }
        }
    }

    /// Answers one call. A caller that stopped before its whole request arrived gets nothing, and changes nothing.
    private static func answerNext(on listener: Int32, with answer: @Sendable (Data) async -> Data) async {
        let descriptor = accept(listener, nil, nil)
        guard descriptor >= 0 else { return }
        let connection = Connection(descriptor: descriptor, limit: callerLimit)
        defer { connection.close() }
        guard let request = connection.receive() else { return }
        _ = connection.send(await answer(request))
    }
}

/// One end of a socket between a call and its helper. Each message has its length first, so that a cut one is not read as whole.
private struct Connection: Sendable {
    private static let chunk = 65_536

    private let descriptor: Int32

    /// The address of a path, or nil when the path is too long for one.
    static func address(of path: String) -> sockaddr_un? {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: address.sun_path) else { return nil }
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
        return address
    }

    /// Connects to a socket, or returns nil when nothing listens on it.
    init?(path: String) {
        guard let address = Self.address(of: path) else { return nil }
        descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { return nil }
        let result = withUnsafePointer(to: address) { [descriptor] in
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard result == 0 else {
            Darwin.close(descriptor)
            return nil
        }
    }

    /// Takes a connection that the helper accepted, with a limit in seconds on each read and write.
    init(descriptor: Int32, limit: Int) {
        self.descriptor = descriptor
        var time = timeval(tv_sec: limit, tv_usec: 0)
        setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &time, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(descriptor, SOL_SOCKET, SO_SNDTIMEO, &time, socklen_t(MemoryLayout<timeval>.size))
    }

    func close() {
        Darwin.close(descriptor)
    }

    /// Sends one message, and returns whether all of it went.
    func send(_ message: Data) -> Bool {
        var length = UInt64(message.count).littleEndian
        return withUnsafeBytes(of: &length) { write($0) } && message.withUnsafeBytes { write($0) }
    }

    /// Reads one message, or returns nil when the other end stops before all of it arrives.
    func receive() -> Data? {
        guard let head = read(count: MemoryLayout<UInt64>.size) else { return nil }
        let length = head.reduce(UInt64(0)) { ($0 >> 8) | (UInt64($1) << 56) }
        return read(count: Int(length))
    }

    private func write(_ bytes: UnsafeRawBufferPointer) -> Bool {
        var offset = 0
        while offset < bytes.count {
            let count = Darwin.write(descriptor, bytes.baseAddress! + offset, bytes.count - offset)
            if count > 0 {
                offset += count
            } else if errno != EINTR {
                return false
            }
        }
        return true
    }

    private func read(count: Int) -> Data? {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: Self.chunk)
        while data.count < count {
            let got = Darwin.read(descriptor, &buffer, min(Self.chunk, count - data.count))
            if got > 0 {
                data.append(contentsOf: buffer[..<got])
            } else if got == 0 || errno != EINTR {
                return nil
            }
        }
        return data
    }
}
