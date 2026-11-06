import Foundation

extension String {
    /// Writes this text as an executable script. macOS checks each new executable file on its first run, for about 150 ms,
    /// so this reuses a file that it already checked: a file in the shared folder with no other name is free to take.
    func writeScript(to url: URL) throws {
        let shared = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-test-scripts", isDirectory: true)
        try FileManager.default.createDirectory(at: shared, withIntermediateDirectories: true)
        let claim = url.path + ".\(UUID().uuidString)"
        var slot = 0
        while true {
            let file = shared.appendingPathComponent("\(slot)").path
            slot += 1
            let made = open(file, O_CREAT | O_EXCL | O_WRONLY, 0o755)
            if made >= 0 { close(made) }
            guard Self.names(of: file) == 1 else { continue }
            guard link(file, claim) == 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
            guard Self.names(of: file) == 2 else {
                unlink(claim)
                continue
            }
            let handle = try FileHandle(forWritingAtPath: claim).orThrow()
            try handle.truncate(atOffset: 0)
            try handle.write(contentsOf: Data(utf8))
            try handle.close()
            chmod(claim, 0o755)
            guard rename(claim, url.path) == 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
            return
        }
    }

    /// The number of names that a file has, which is 0 when the file is gone.
    private static func names(of path: String) -> Int {
        var info = stat()
        return stat(path, &info) == 0 ? Int(info.st_nlink) : 0
    }
}

private extension Optional {
    func orThrow() throws -> Wrapped {
        guard let self else { throw POSIXError(.ENOENT) }
        return self
    }
}
