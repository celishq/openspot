import Foundation

public struct PluginRun: Sendable {
    public let plugin: Plugin
    public let query: String
    public let timeout: TimeInterval

    public init(plugin: Plugin, query: String, timeout: TimeInterval) {
        self.plugin = plugin
        self.query = query
        self.timeout = timeout
    }

    public func execute() async throws -> RowResult {
        try await withThrowingTaskGroup(of: RowResult.self) { group in
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

    private func runProcess() async throws -> RowResult {
        let process = Process()
        process.executableURL = plugin.url
        process.arguments = [query]
        process.standardInput = FileHandle.nullDevice
        let output = Pipe()
        process.standardOutput = output
        try process.run()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global().async {
                    let data = output.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    guard process.terminationStatus == 0 else {
                        continuation.resume(throwing: PluginError.failed(process.terminationStatus))
                        return
                    }
                    continuation.resume(returning: RowResult(output: String(decoding: data, as: UTF8.self)))
                }
            }
        } onCancel: {
            process.terminate()
        }
    }
}
