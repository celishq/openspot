import Foundation

public struct PluginRun: Sendable {
    public let url: URL
    public let arguments: [String]
    public let timeout: TimeInterval
    public let input: String?

    public init(command: PluginCommand, arguments: [String], timeout: TimeInterval, input: String? = nil) {
        url = command.url
        self.arguments = arguments
        self.timeout = timeout
        self.input = input
    }

    public init(url: URL, arguments: [String], timeout: TimeInterval, input: String? = nil) {
        self.url = url
        self.arguments = arguments
        self.timeout = timeout
        self.input = input
    }

    /// The environment of a script, with the `openspot` command of this app on its path and the data folder, which this
    /// creates.
    public static func environment(base: [String: String], app: String) -> [String: String] {
        let helpers = URL(fileURLWithPath: app).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Helpers").path
        let home = base["HOME"].map { URL(fileURLWithPath: $0, isDirectory: true) } ?? FileManager.default.homeDirectoryForCurrentUser
        let data = PluginFolder.config(environment: base, home: home).appendingPathComponent("data", isDirectory: true)
        try? FileManager.default.createDirectory(at: data, withIntermediateDirectories: true)
        return base.merging(["PATH": "\(helpers):\(base["PATH"] ?? "")", "OPENSPOT_DATA": data.path], uniquingKeysWith: { _, new in new })
    }

    /// Runs the plugin with the arguments, and returns what it prints.
    public func output() async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask { try await self.runProcess() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(self.timeout * 1_000_000_000))
                throw PluginError.timedOut
            }
            let first = try await group.next()!
            group.cancelAll()
            return first
        }
    }

    /// Runs the plugin and gives each frame as the plugin prints it. A line `---` ends a frame, and so does the end of the
    /// output. Only the first frame has a time limit. Ending the stream stops the plugin.
    public func frames() -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let process = Process()
            process.executableURL = url
            process.environment = Self.environment(base: ProcessInfo.processInfo.environment, app: Bundle.main.executablePath ?? "")
            process.arguments = arguments
            let inputPipe = input.map { _ in Pipe() }
            process.standardInput = inputPipe ?? FileHandle.nullDevice
            let output = Pipe()
            process.standardOutput = output
            let errors = Pipe()
            process.standardError = errors
            let exit = DispatchSemaphore(value: 0)
            process.terminationHandler = { _ in exit.signal() }
            do {
                try process.run()
            } catch {
                continuation.finish(throwing: error)
                return
            }
            if let inputPipe, let input {
                signal(SIGPIPE, SIG_IGN)
                DispatchQueue.global().async {
                    try? inputPipe.fileHandleForWriting.write(contentsOf: Data(input.utf8))
                    try? inputPipe.fileHandleForWriting.close()
                }
            }
            let start = StreamStart()
            continuation.onTermination = { _ in process.terminate() }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                guard !start.hasFrame else { return }
                continuation.finish(throwing: PluginError.timedOut)
                process.terminate()
            }
            let lastErrors = StreamText()
            DispatchQueue.global().async {
                lastErrors.text = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            }
            DispatchQueue.global().async {
                var reader = SheetFrameReader()
                while true {
                    let data = output.fileHandleForReading.availableData
                    if data.isEmpty { break }
                    for frame in reader.read(data) {
                        start.markFrame()
                        continuation.yield(frame)
                    }
                }
                exit.wait()
                guard process.terminationStatus == 0 || process.terminationReason == .uncaughtSignal else {
                    let line = lastErrors.text.split(separator: "\n").last.map(String.init) ?? ""
                    continuation.finish(throwing: PluginError.failed(process.terminationStatus, line))
                    return
                }
                if let frame = reader.finish() {
                    start.markFrame()
                    continuation.yield(frame)
                }
                start.markFrame()
                continuation.finish()
            }
        }
    }

    private func runProcess() async throws -> String {
        let process = Process()
        process.executableURL = url
        process.environment = Self.environment(base: ProcessInfo.processInfo.environment, app: Bundle.main.executablePath ?? "")
        process.arguments = arguments
        let inputPipe = input.map { _ in Pipe() }
        process.standardInput = inputPipe ?? FileHandle.nullDevice
        let output = Pipe()
        process.standardOutput = output
        let errors = Pipe()
        process.standardError = errors
        let exit = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exit.signal() }
        try process.run()
        if let inputPipe, let input {
            signal(SIGPIPE, SIG_IGN)
            DispatchQueue.global().async {
                try? inputPipe.fileHandleForWriting.write(contentsOf: Data(input.utf8))
                try? inputPipe.fileHandleForWriting.close()
            }
        }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global().async {
                    let data = output.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errors.fileHandleForReading.readDataToEndOfFile()
                    exit.wait()
                    guard process.terminationStatus == 0 else {
                        let lines = String(decoding: errorData, as: UTF8.self).split(separator: "\n")
                        continuation.resume(throwing: PluginError.failed(process.terminationStatus, lines.last.map(String.init) ?? ""))
                        return
                    }
                    continuation.resume(returning: String(decoding: data, as: UTF8.self))
                }
            }
        } onCancel: {
            process.terminate()
        }
    }
}

/// Whether a stream has given its first frame, which ends its time limit.
final class StreamStart: @unchecked Sendable {
    private let lock = NSLock()
    private var frame = false

    var hasFrame: Bool {
        lock.withLock { frame }
    }

    func markFrame() {
        lock.withLock { frame = true }
    }
}

/// Text that one queue writes and another reads.
final class StreamText: @unchecked Sendable {
    private let lock = NSLock()
    private var value = ""

    var text: String {
        get { lock.withLock { value } }
        set { lock.withLock { value = newValue } }
    }
}
