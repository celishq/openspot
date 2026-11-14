import CryptoKit
import Foundation

public struct SwiftProgram: Sendable {
    static let sourceExtension = "swift"
    private static let programExtension = "program"
    private static let platform = "apple-macos26.0"
    static let kinds = ["arm64", "x86_64"]

    private static let lock = NSLock()
    nonisolated(unsafe) private static var started: Set<String> = []
    nonisolated(unsafe) private static var hashes: [String: (stamp: [Int], hash: String)] = [:]
    private static let magics: Set<[UInt8]> = [[0xcf, 0xfa, 0xed, 0xfe], [0xca, 0xfe, 0xba, 0xbe]]
    private static let day: TimeInterval = 86_400
    private static let unusedDays: TimeInterval = 30
    private static let pruneMark = ".pruned"
    private static let folderNameLength = 12

    private let tools: URL
    let cache: URL
    private let now: @Sendable () -> Date

    public init(tools: URL = URL(fileURLWithPath: "/usr/bin", isDirectory: true), cache: URL? = nil, now: @escaping @Sendable () -> Date = { Date() }) {
        self.tools = tools
        self.now = now
        let environment = ProcessInfo.processInfo.environment
        let home = URL(fileURLWithPath: environment["HOME"] ?? NSHomeDirectory(), isDirectory: true)
        self.cache = cache ?? Self.folder(of: SpotsFolder.config(environment: environment, home: home), in: home.appendingPathComponent("Library/Caches/dev.openspot/swift", isDirectory: true))
    }

    static func folder(of config: URL, in root: URL) -> URL {
        let hash = SHA256.hash(data: Data(config.standardizedFileURL.path.utf8)).map { String(format: "%02x", $0) }.joined()
        return root.appendingPathComponent(String(hash.prefix(folderNameLength)), isDirectory: true)
    }

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

    private func adopt(_ name: String) {
        let old = cache.deletingLastPathComponent().appendingPathComponent(name)
        guard Self.isWhole(old) else { return }
        try? FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        _ = rename(old.path, cache.appendingPathComponent(name).path)
    }

    private static func isBuildName(_ name: String) -> Bool {
        name.count == 64 && name.allSatisfy(\.isHexDigit)
    }

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

    private static func isWhole(_ program: URL) -> Bool {
        guard FileManager.default.isExecutableFile(atPath: program.path), let handle = try? FileHandle(forReadingFrom: program) else { return false }
        defer { try? handle.close() }
        return (try? handle.read(upToCount: 4)).map { magics.contains(Array($0)) } ?? false
    }

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

    static func isProgram(_ url: URL) -> Bool {
        url.pathExtension == programExtension
    }

    static func path(beside source: String) -> String? {
        let url = URL(fileURLWithPath: source)
        guard url.pathExtension == sourceExtension else { return nil }
        return String(source.dropLast(sourceExtension.count)) + programExtension
    }

    static func file(beside source: URL) -> URL? {
        guard let path = path(beside: source.path), FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path)
    }

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
