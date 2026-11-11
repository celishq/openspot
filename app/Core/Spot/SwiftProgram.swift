import CryptoKit
import Foundation

/// The compiled form of a Swift script, which travels beside its source so that a Mac with no Swift tools can run it, or
/// which a first run builds once into a cache, named by the hash of its source. Each config folder has a cache of its own,
/// so that the prune of a Debug build keeps the builds of the installed app. A prune keeps the cache to the builds of the
/// sources that are there and that ran in the last 30 days.
public struct SwiftProgram: Sendable {
    static let sourceExtension = "swift"
    private static let programExtension = "program"
    private static let platform = "apple-macos26.0"
    /// The kinds of Mac that a shared build runs on.
    static let kinds = ["arm64", "x86_64"]

    /// The programs that build now, or that failed to build in this run of the app.
    private static let lock = NSLock()
    nonisolated(unsafe) private static var started: Set<String> = []
    /// The hash of each source by its path, with the stamp of the file it was read from.
    nonisolated(unsafe) private static var hashes: [String: (stamp: [Int], hash: String)] = [:]
    /// The first bytes of a program for one kind of Mac, and of a universal one.
    private static let magics: Set<[UInt8]> = [[0xcf, 0xfa, 0xed, 0xfe], [0xca, 0xfe, 0xba, 0xbe]]
    private static let day: TimeInterval = 86_400
    /// The days with no run after which a prune removes a build.
    private static let unusedDays: TimeInterval = 30
    /// The file whose date of change is the time of the last prune.
    private static let pruneMark = ".pruned"
    /// The length of the name of the cache of a config folder, from the hash of its path.
    private static let folderName = 12

    private let tools: URL
    let cache: URL
    private let now: @Sendable () -> Date

    /// `tools` is the folder that holds `xcode-select`, `swiftc` and `lipo`. `cache` holds the program that a first run of
    /// each source builds, by default the folder of this config folder in the caches of the home, where no spot in Careful
    /// mode can write.
    public init(tools: URL = URL(fileURLWithPath: "/usr/bin", isDirectory: true), cache: URL? = nil, now: @escaping @Sendable () -> Date = { Date() }) {
        self.tools = tools
        self.now = now
        let environment = ProcessInfo.processInfo.environment
        let home = URL(fileURLWithPath: environment["HOME"] ?? NSHomeDirectory(), isDirectory: true)
        self.cache = cache ?? Self.folder(of: SpotFolder.config(environment: environment, home: home), in: home.appendingPathComponent("Library/Caches/dev.openspot/swift", isDirectory: true))
    }

    /// The cache of the builds of a config folder: a folder in `root` named by a short hash of the folder's path.
    static func folder(of config: URL, in root: URL) -> URL {
        let hash = SHA256.hash(data: Data(config.standardizedFileURL.path.utf8)).map { String(format: "%02x", $0) }.joined()
        return root.appendingPathComponent(String(hash.prefix(folderName)), isDirectory: true)
    }

    /// What runs a script: the program beside it, the built program of a Swift source in the cache, or else the file
    /// itself. With `builds`, a Swift source with no whole program in the cache starts its build, and runs itself meanwhile.
    func runnable(for script: URL, builds: Bool = true) -> URL {
        if let program = Self.file(beside: script) { return program }
        guard script.pathExtension == Self.sourceExtension, let name = Self.hash(of: script) else { return script }
        let program = cache.appendingPathComponent(name)
        if !Self.isWhole(program) { adopt(name) }
        if Self.isWhole(program) {
            markUsed(program)
            return program
        }
        guard builds, Self.lock.withLock({ Self.started.insert(program.path).inserted }) else { return script }
        Task.detached(priority: .utility) { [self] in
            if let source = try? Data(contentsOf: script), (try? await cached(source, at: program)) != nil { Self.lock.withLock { _ = Self.started.remove(program.path) } }
        }
        return script
    }

    /// Removes each build whose hash is no source of these scripts, and each build that did not run for 30 days, apart from
    /// a build that runs now, and so too each build that an older app kept in the folder that all config folders shared. It
    /// runs at most once a day, on a thread of its own, and returns nil when it does not run.
    @discardableResult
    func prune(keeping scripts: [URL]) -> Task<Void, Never>? {
        let date = now()
        let mark = cache.appendingPathComponent(Self.pruneMark)
        if let last = Self.changed(mark), date.timeIntervalSince(last) < Self.day { return nil }
        try? FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        guard FileManager.default.createFile(atPath: mark.path, contents: nil, attributes: [.modificationDate: date]) else { return nil }
        let sources = scripts.filter { $0.pathExtension == Self.sourceExtension }
        return Task.detached(priority: .utility) { [cache] in
            let kept = Set(sources.compactMap(Self.hash(of:)))
            let running = Self.runningPrograms()
            let names = (try? FileManager.default.contentsOfDirectory(atPath: cache.path)) ?? []
            for name in names where !name.hasPrefix(".") {
                let program = cache.appendingPathComponent(name)
                let isStale = date.timeIntervalSince(Self.changed(program) ?? date) > Self.unusedDays * Self.day
                guard !kept.contains(name) || isStale, !running.contains(Self.real(program)) else { continue }
                try? FileManager.default.removeItem(at: program)
            }
            let shared = cache.deletingLastPathComponent()
            for name in (try? FileManager.default.contentsOfDirectory(atPath: shared.path)) ?? [] where Self.isBuildName(name) {
                let program = shared.appendingPathComponent(name)
                let isStale = date.timeIntervalSince(Self.changed(program) ?? date) > Self.unusedDays * Self.day
                guard isStale, !running.contains(Self.real(program)) else { continue }
                try? FileManager.default.removeItem(at: program)
            }
        }
    }

    /// Moves the build of this name from the folder that all config folders shared into this cache, when an older app kept
    /// one there.
    private func adopt(_ name: String) {
        let old = cache.deletingLastPathComponent().appendingPathComponent(name)
        guard Self.isWhole(old) else { return }
        try? FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        _ = rename(old.path, cache.appendingPathComponent(name).path)
    }

    /// Whether a name is that of a build: the 64 hex digits of the hash of its source.
    private static func isBuildName(_ name: String) -> Bool {
        name.count == 64 && name.allSatisfy(\.isHexDigit)
    }

    /// Dates a build to now when its last run is more than a day old, so that a prune knows it runs.
    private func markUsed(_ program: URL) {
        let date = now()
        guard let last = Self.changed(program), date.timeIntervalSince(last) > Self.day else { return }
        try? FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: program.path)
    }

    private static func changed(_ file: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: file.path))?[.modificationDate] as? Date
    }

    private static func real(_ file: URL) -> String {
        guard let path = realpath(file.path, nil) else { return file.path }
        defer { free(path) }
        return String(cString: path)
    }

    /// The path of the program of each process that runs now.
    private static func runningPrograms() -> Set<String> {
        var ids = [pid_t](repeating: 0, count: Int(proc_listallpids(nil, 0)) + 64)
        let count = Int(proc_listallpids(&ids, Int32(ids.count * MemoryLayout<pid_t>.size)))
        var paths: Set<String> = []
        var buffer = [UInt8](repeating: 0, count: Int(MAXPATHLEN))
        for id in ids.prefix(max(count, 0)) {
            let length = proc_pidpath(id, &buffer, UInt32(buffer.count))
            if length > 0 { paths.insert(String(decoding: buffer[..<Int(length)], as: UTF8.self)) }
        }
        return paths
    }

    /// The SHA-256 of a source, read again only when its size, its file number or its date of change moved.
    private static func hash(of script: URL) -> String? {
        var info = stat()
        guard stat(script.path, &info) == 0 else { return nil }
        let stamp = [Int(info.st_size), Int(info.st_ino), info.st_mtimespec.tv_sec, info.st_mtimespec.tv_nsec]
        if let known = lock.withLock({ hashes[script.path] }), known.stamp == stamp { return known.hash }
        guard let source = try? Data(contentsOf: script) else { return nil }
        let hash = SHA256.hash(data: source).map { String(format: "%02x", $0) }.joined()
        lock.withLock { hashes[script.path] = (stamp, hash) }
        return hash
    }

    /// Whether a file is an executable program, which a build cut short or a stray write is not.
    private static func isWhole(_ program: URL) -> Bool {
        guard FileManager.default.isExecutableFile(atPath: program.path), let handle = try? FileHandle(forReadingFrom: program) else { return false }
        defer { try? handle.close() }
        return (try? handle.read(upToCount: 4)).map { magics.contains(Array($0)) } ?? false
    }

    /// Builds a source for this Mac in a work folder of the temp folder, and puts it at its place in the cache over any file
    /// there.
    private func cached(_ source: Data, at program: URL) async throws {
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-swift-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }
        let file = work.appendingPathComponent("main.swift")
        try source.write(to: file)
        let built = work.appendingPathComponent("program")
        _ = try await ScriptProcess.output(url: tool("swiftc"), arguments: ["-O", "-module-name", "Spot", file.path, "-o", built.path])
        guard Self.isWhole(built) else { throw SpotError.fault("swiftc wrote no program.") }
        let placed = cache.appendingPathComponent(".\(program.lastPathComponent)-\(UUID().uuidString)")
        try FileManager.default.moveItem(at: built, to: placed)
        guard rename(placed.path, program.path) == 0 else {
            try? FileManager.default.removeItem(at: placed)
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }

    /// Whether a file of this name is a compiled program, which only its source runs.
    static func isProgram(_ url: URL) -> Bool {
        url.pathExtension == programExtension
    }

    /// The path of the program of a Swift script, or nil for a path that is no Swift script.
    static func path(beside source: String) -> String? {
        let url = URL(fileURLWithPath: source)
        guard url.pathExtension == sourceExtension else { return nil }
        return String(source.dropLast(sourceExtension.count)) + programExtension
    }

    /// The program of a Swift script that exists on the disk.
    static func file(beside source: URL) -> URL? {
        guard let path = path(beside: source.path), FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path)
    }

    /// Compiles one source for both kinds of Mac, and returns the universal program.
    public func build(source: Data) async throws -> Data {
        do {
            _ = try await ScriptProcess.output(url: tool("xcode-select"), arguments: ["-p"])
        } catch {
            throw SpotError.fault("To share a Swift spot, install the Command Line Tools: xcode-select --install")
        }
        let place = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-build-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: place) }
        let file = place.appendingPathComponent("spot.swift")
        try source.write(to: file)
        var parts: [String] = []
        for kind in Self.kinds {
            let part = place.appendingPathComponent(kind).path
            parts.append(part)
            do {
                let arguments = ["-O", "-module-name", "Spot", "-target", "\(kind)-\(Self.platform)", file.path, "-o", part]
                _ = try await ScriptProcess.output(url: tool("swiftc"), arguments: arguments)
            } catch {
                throw SpotError.fault("This Swift spot does not compile. \((error as? SpotError)?.reason ?? String(describing: error))")
            }
        }
        let program = place.appendingPathComponent("program")
        _ = try await ScriptProcess.output(url: tool("lipo"), arguments: ["-create"] + parts + ["-output", program.path])
        return try Data(contentsOf: program)
    }

    private func tool(_ name: String) -> URL {
        tools.appendingPathComponent(name)
    }
}
