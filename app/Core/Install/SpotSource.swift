import Foundation

/// Where a spot comes from: a git repository, a folder or a `.spot` file (N1). It puts the spot at the top of a plugins
/// folder, and runs nothing of it.
public enum SpotSource: Equatable, Sendable {
    /// A git URL, or the path of a folder that git keeps.
    case git(String)
    case folder(URL)
    case file(URL)

    private static let git = URL(fileURLWithPath: "/usr/bin/git")

    /// Reads the words of a source: a path that exists, from `place` when it is relative, or else a git URL.
    public init(text: String, place: URL) {
        let expanded = (text as NSString).expandingTildeInPath
        let url = expanded.hasPrefix("/") ? URL(fileURLWithPath: expanded) : place.appendingPathComponent(expanded)
        var isFolder: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isFolder) else {
            self = .git(text)
            return
        }
        let path = url.standardizedFileURL
        if !isFolder.boolValue {
            self = .file(path)
        } else if FileManager.default.fileExists(atPath: path.appendingPathComponent(".git").path) {
            self = .git(path.path)
        } else {
            self = .folder(path)
        }
    }

    /// The source as `spots.lock` keeps it: the URL, or the whole path.
    public var text: String {
        switch self {
        case .git(let text): text
        case .folder(let url), .file(let url): url.path
        }
    }

    /// Puts the spot in the folder, a git source at `commit` or else at its newest commit, and returns the commit and the
    /// paths at the top of the folder that it took. A path that is there already is a fault, unless `replacing` names it:
    /// then `discard` takes each replaced path, and each one the new version lacks, as the Trash does. `check` sees the whole
    /// spot in a work folder first, and a throw from it, as any fault or a stop of the task, leaves the folder as it was.
    func add(
        to folder: URL,
        at commit: String?,
        replacing: [String] = [],
        discard: (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) },
        check: (URL, [String]) throws -> Void = { _, _ in }
    ) async throws -> (commit: String?, paths: [String]) {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let work = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: folder, create: true)
        defer { try? FileManager.default.removeItem(at: work) }
        let (commit, paths) = try await stage(in: work, from: folder, at: commit, replacing: replacing)
        try check(work, paths)
        try Task.checkCancellation()
        for path in replacing where FileManager.default.fileExists(atPath: folder.appendingPathComponent(path).path) {
            try discard(folder.appendingPathComponent(path))
        }
        for path in paths {
            try FileManager.default.moveItem(at: work.appendingPathComponent(path), to: folder.appendingPathComponent(path))
        }
        return (commit, paths)
    }

    /// Writes the spot whole into a work folder, so that a failure leaves the plugins folder as it was.
    private func stage(in work: URL, from folder: URL, at commit: String?, replacing: [String]) async throws -> (commit: String?, paths: [String]) {
        switch self {
        case .git(let text):
            if text.hasPrefix("/"), !FileManager.default.fileExists(atPath: text) { throw SpotError.fault("Openspot cannot find \(text).") }
            let name = try Self.name(of: text)
            try Self.checkFree([name], in: folder, replacing: replacing)
            let clone = work.appendingPathComponent(name)
            do {
                try await Self.run(["clone", "--quiet", text, clone.path])
                if let commit { try await Self.run(["-C", clone.path, "checkout", "--quiet", "--detach", commit]) }
                let head = try await Self.run(["-C", clone.path, "rev-parse", "HEAD"]).trimmingCharacters(in: .whitespacesAndNewlines)
                try FileManager.default.removeItem(at: clone.appendingPathComponent(".git"))
                return (head, [name])
            } catch let error as SpotError {
                throw SpotError.fault("Openspot cannot add \(text). \(error.reason)")
            }
        case .folder(let url):
            let name = url.lastPathComponent
            try Self.checkFree([name], in: folder, replacing: replacing)
            try FileManager.default.copyItem(at: url, to: work.appendingPathComponent(name))
            return (nil, [name])
        case .file(let url):
            let spot = try SharedSpot(contentsOf: url)
            var paths: [String] = []
            for file in spot.files {
                let top = String(file.path.split(separator: "/")[0])
                if !paths.contains(top) { paths.append(top) }
            }
            try Self.checkFree(paths, in: folder, replacing: replacing)
            try spot.add(to: work)
            return (nil, paths)
        }
    }

    /// The name of the folder of a git source: the last part of its URL or path, with no `.git`.
    private static func name(of text: String) throws -> String {
        var path = text
        while path.hasSuffix("/") { path.removeLast() }
        if path.hasSuffix("/.git") { path.removeLast(5) }
        if path.hasSuffix(".git") { path.removeLast(4) }
        guard let name = path.split(whereSeparator: { $0 == "/" || $0 == ":" }).last.map(String.init), !name.hasPrefix(".") else {
            throw SpotError.fault("Openspot cannot name a folder for \(text). Give the URL of a git repository.")
        }
        return name
    }

    private static func checkFree(_ paths: [String], in folder: URL, replacing: [String]) throws {
        for path in paths where !replacing.contains(path) && FileManager.default.fileExists(atPath: folder.appendingPathComponent(path).path) {
            let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            throw SpotError.fault("The plugins folder has \(path) already. Run `openspot spot remove \(name)` first, or move it away.")
        }
    }

    /// Runs git with no input and no prompt for a password, and returns what it prints, which must fit in a pipe. A failure
    /// throws its last line on stderr, and a stop of the task ends git and throws.
    @discardableResult
    private static func run(_ arguments: [String]) async throws -> String {
        let process = Process()
        process.executableURL = git
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.environment = ProcessInfo.processInfo.environment.merging(["GIT_TERMINAL_PROMPT": "0"]) { _, new in new }
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        let printed: String = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let ended = DispatchSemaphore(value: 0)
                process.terminationHandler = { _ in ended.signal() }
                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: SpotError.fault("Openspot cannot start git. Run `xcode-select --install`, then try again."))
                    return
                }
                if Task.isCancelled { process.terminate() }
                DispatchQueue.global().async {
                    let failure = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                    let printed = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                    ended.wait()
                    guard process.terminationStatus != 0 else { return continuation.resume(returning: printed) }
                    let line = failure.split(separator: "\n").last.map(String.init) ?? "git stopped with code \(process.terminationStatus)."
                    continuation.resume(throwing: SpotError.fault(line))
                }
            }
        } onCancel: {
            if process.isRunning { process.terminate() }
        }
        try Task.checkCancellation()
        return printed
    }
}
