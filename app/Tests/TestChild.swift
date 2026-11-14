import Foundation

final class TestChild {
    private let process = Process()
    private let ended = DispatchSemaphore(value: 0)

    init(_ path: String, _ arguments: [String], output: Pipe? = nil) throws {
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        if let output { process.standardOutput = output }
        process.terminationHandler = { [ended] _ in ended.signal() }
        try process.run()
    }

    var processIdentifier: pid_t { process.processIdentifier }

    @discardableResult
    func stop() -> Bool {
        process.terminate()
        return ended.wait(timeout: .now() + 10) == .success
    }
}
