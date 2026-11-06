import Foundation

/// A script that stays running: it takes one block on its standard input for each event, and prints frames. A model or a
/// connection that it loads stays loaded between events. Closing its input tells it to end.
public final class LiveScript: @unchecked Sendable {
    private let url: URL
    private let timeout: TimeInterval
    private let process = Process()
    private let input = Pipe()
    private let writes = DispatchQueue(label: "openspot.live")

    public init(url: URL, timeout: TimeInterval) {
        self.url = url
        self.timeout = timeout
    }

    /// Starts the script, and returns its frames. Only the first frame has a time limit.
    public func start() throws -> AsyncThrowingStream<String, Error> {
        process.executableURL = url
        process.environment = PluginRun.environment(base: ProcessInfo.processInfo.environment, app: Bundle.main.executablePath ?? "")
        process.standardInput = input
        let output = Pipe()
        process.standardOutput = output
        let errors = Pipe()
        process.standardError = errors
        let exit = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exit.signal() }
        signal(SIGPIPE, SIG_IGN)
        try process.run()
        let process = process
        let timeout = timeout
        return AsyncThrowingStream { continuation in
            let start = StreamStart()
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
                start.markFrame()
                if process.terminationStatus != 0, process.terminationReason != .uncaughtSignal {
                    let line = lastErrors.text.split(separator: "\n").last.map(String.init) ?? ""
                    continuation.finish(throwing: PluginError.failed(process.terminationStatus, line))
                } else {
                    continuation.finish()
                }
            }
        }
    }

    /// Sends one event to the script, in the order of the calls.
    public func send(_ action: SpotAction) {
        let handle = input.fileHandleForWriting
        let text = action.event
        writes.async { try? handle.write(contentsOf: Data(text.utf8)) }
    }

    /// Closes its input, which ends a script that reads to the end, and then stops it.
    public func stop() {
        let handle = input.fileHandleForWriting
        let process = process
        writes.async {
            try? handle.close()
            if process.isRunning { process.terminate() }
        }
    }

    public var isRunning: Bool {
        process.isRunning
    }
}
