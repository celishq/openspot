import Foundation

extension String {
    /// The loop of a test script that ignores the terminate signal. It ends by itself, so that a test run that dies leaves
    /// nothing that runs for ever.
    static let deafLoop = "seq 300 | while read i; do sleep 0.1; done"

    /// Writes this text as an executable script. macOS checks each new executable file on its first run, for 150 ms or more,
    /// which a short time limit in a test can miss. So this takes a file that already ran: a file in the shared folder with
    /// no other name is free to take, and with none free it runs a new one first.
    func writeScript(to url: URL) throws {
        let shared = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-test-scripts", isDirectory: true)
        try FileManager.default.createDirectory(at: shared, withIntermediateDirectories: true)
        let claim = url.path + ".\(UUID().uuidString)"
        while true {
            for name in try FileManager.default.contentsOfDirectory(atPath: shared.path) where !name.hasSuffix(".new") {
                let file = shared.appendingPathComponent(name).path
                guard Self.names(of: file) == 1 else { continue }
                guard link(file, claim) == 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
                guard Self.names(of: file) == 2 else {
                    unlink(claim)
                    continue
                }
                let handle = FileHandle(forWritingAtPath: claim)
                try handle?.truncate(atOffset: 0)
                try handle?.write(contentsOf: Data(utf8))
                try handle?.close()
                chmod(claim, 0o755)
                guard rename(claim, url.path) == 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
                return
            }
            try Self.addFile(to: shared)
        }
    }

    /// The number of names that a file has, which is 0 when the file is gone.
    private static func names(of path: String) -> Int {
        var info = stat()
        return stat(path, &info) == 0 ? Int(info.st_nlink) : 0
    }

    /// Adds a file to the folder after its first run, so that no other process takes it before that.
    private static func addFile(to folder: URL) throws {
        let name = UUID().uuidString
        let new = folder.appendingPathComponent(name + ".new")
        try "#!/bin/sh\n".write(to: new, atomically: false, encoding: .utf8)
        chmod(new.path, 0o755)
        let process = Process()
        process.executableURL = new
        let ended = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in ended.signal() }
        try process.run()
        ended.wait()
        try FileManager.default.moveItem(at: new, to: folder.appendingPathComponent(name))
    }
}
