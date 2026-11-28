import Foundation

/// A command that the spot runs, such as `openspot clipboard paste` or `whisper-server`, found on its `PATH`.
enum Tool {
    /// The path of a command on the `PATH`, or nil when no folder of the `PATH` holds it.
    static func path(of name: String) -> String? {
        let folders = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":")
        return folders.map { "\($0)/\(name)" }.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Runs a command and waits for it, and gives its stdout, or nil when it fails.
    static func output(of arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? String(decoding: data, as: UTF8.self) : nil
    }

    /// Runs a command with a text on its stdin, and gives its exit code, its stdout and its stderr on the main queue. A
    /// command that runs longer than `limit` is stopped.
    static func run(_ arguments: [String], input: String = "", limit: TimeInterval? = nil, done: @escaping (Int32, String, String) -> Void = { _, _, _ in }) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr
        do {
            try process.run()
        } catch {
            return done(127, "", "Openspot cannot run `\(arguments.first ?? "")`.")
        }
        DispatchQueue.global().async {
            stdin.fileHandleForWriting.write(Data(input.utf8))
            try? stdin.fileHandleForWriting.close()
            let out = stdout.fileHandleForReading.readDataToEndOfFile()
            let fault = stderr.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let words = (String(decoding: out, as: UTF8.self), String(decoding: fault, as: UTF8.self))
            DispatchQueue.main.async { done(process.terminationStatus, words.0, words.1) }
        }
        if let limit {
            DispatchQueue.main.asyncAfter(deadline: .now() + limit) {
                if process.isRunning { process.terminate() }
            }
        }
    }
}
