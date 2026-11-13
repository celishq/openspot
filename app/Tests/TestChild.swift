import Foundation

/// A process that a test starts and ends. `stop()` waits for its end with no run loop, which the thread of an async test
/// does not run, so it returns even where `waitUntilExit` would not.
final class TestChild {
    private let process = Process()
    private let ended = DispatchSemaphore(value: 0)

    /// Starts the program with these arguments, and `output` as its stdout when given.
    init(_ path: String, _ arguments: [String], output: Pipe? = nil) throws {
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        if let output { process.standardOutput = output }
        process.terminationHandler = { [ended] _ in ended.signal() }
        try process.run()
    }

    var processIdentifier: pid_t { process.processIdentifier }

    /// Ends it, and whether it ended within ten seconds.
    @discardableResult
    func stop() -> Bool {
        process.terminate()
        return ended.wait(timeout: .now() + 10) == .success
    }
}
