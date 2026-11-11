import Foundation

/// A git repository of a test in a folder of its own, made with the git of the Mac and none of the person's git config.
struct GitRepo {
    let url: URL

    init(at url: URL) throws {
        self.url = url
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try git(["init", "--quiet", "--initial-branch=main"])
    }

    /// Writes each file, with a script as an executable, commits all, and returns the commit.
    @discardableResult
    func commit(_ files: [String: String], message: String = "change") throws -> String {
        for (path, text) in files {
            let file = url.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            if path.hasSuffix(".sh") { try text.writeScript(to: file) } else { try text.write(to: file, atomically: true, encoding: .utf8) }
        }
        try git(["add", "--all"])
        try git(["commit", "--quiet", "--message", message])
        return try git(["rev-parse", "HEAD"]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @discardableResult
    private func git(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", url.path] + arguments
        process.environment = [
            "PATH": "/usr/bin:/bin", "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_AUTHOR_NAME": "Test", "GIT_AUTHOR_EMAIL": "test@example.com", "GIT_COMMITTER_NAME": "Test", "GIT_COMMITTER_EMAIL": "test@example.com"
        ]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw CocoaError(.executableLoad) }
        return text
    }
}
