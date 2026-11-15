import Foundation

extension String {
    static let longLoop = "i=0; while [ $i -lt 300 ]; do sleep 0.1; i=$((i + 1)); done"

    func writeScript(to url: URL) throws {
        let shared = Self.pool
        try FileManager.default.createDirectory(at: shared, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
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

    private static let pool: URL = {
        let temp = FileManager.default.temporaryDirectory
        var number = 0
        while true {
            let folder = temp.appendingPathComponent("openspot-test-scripts-\(number)", isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let lock = open(folder.appendingPathComponent(".lock.new").path, O_CREAT | O_RDWR, 0o644)
            if lock >= 0, flock(lock, LOCK_EX | LOCK_NB) == 0 { return folder }
            close(lock)
            number += 1
        }
    }()

    private static func names(of path: String) -> Int {
        var info = stat()
        return stat(path, &info) == 0 ? Int(info.st_nlink) : 0
    }

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
