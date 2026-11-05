import Foundation

public struct PluginRun: Sendable {
    public let command: PluginCommand
    public let arguments: [String]
    public let timeout: TimeInterval
    public let input: String?

    public init(command: PluginCommand, arguments: [String], timeout: TimeInterval, input: String? = nil) {
        self.command = command
        self.arguments = arguments
        self.timeout = timeout
        self.input = input
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

    private func runProcess() async throws -> String {
        let process = Process()
        process.executableURL = command.url
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
