import Foundation

public enum PluginError: Error, Equatable, Sendable {
    case timedOut
    case failed(Int32)
}

public enum PluginRunner {
    public static func run(_ plugin: Plugin, query: String, timeout: TimeInterval) async throws -> RowResult {
        try await withThrowingTaskGroup(of: RowResult.self) { group in
            group.addTask { try await execute(plugin, query: query) }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw PluginError.timedOut
            }
            let first = try await group.next()!
            group.cancelAll()
            return first
        }
    }

    private static func execute(_ plugin: Plugin, query: String) async throws -> RowResult {
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
                    continuation.resume(returning: RowParser.parse(String(decoding: data, as: UTF8.self)))
                }
            }
        } onCancel: {
            process.terminate()
        }
    }
}
