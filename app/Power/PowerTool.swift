import Foundation

enum PowerTool {
    private static let limit: TimeInterval = 10

    static func run(_ path: String, _ arguments: [String]) -> Data? {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let late = DispatchWorkItem { [process] in process.terminate() }
        DispatchQueue.global().asyncAfter(deadline: .now() + limit, execute: late)
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        late.cancel()
        return process.terminationStatus == 0 && process.terminationReason == .exit ? data : nil
    }
}
