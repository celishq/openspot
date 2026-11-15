import CryptoKit
import Foundation
import Synchronization

public struct SwiftProgram: Sendable {
    static let sourceExtension = "swift"
    private static let programExtension = "program"
    private static let mainName = "main.swift"
    private static let hashLength = 64
    private static let flags = ["-O", "-module-name", "Spot"]
    private static let building = Mutex<[String: Task<URL, Error>]>([:])

    private struct Faults {
        var kept: [String: String] = [:]
        var order: [String] = []
    }

    static let faultLimit = 32
    static let toolsFault = "To build a Swift spot, install the Command Line Tools: xcode-select --install"
    private static let nameLimit = 1024
    private static let toolsLimit = 16
    private static let started = Mutex<Set<String>>([])
    private static let names = Mutex<[String: (stamp: [Int], name: String)]>([:])
    private static let faults = Mutex(Faults())
    private static let toolChecks = Mutex<[String: Task<Bool, Never>]>([:])
    private static let magics: Set<[UInt8]> = [[0xcf, 0xfa, 0xed, 0xfe], [0xca, 0xfe, 0xba, 0xbe]]
    private static let day: TimeInterval = 86_400
    private static let unusedDays: TimeInterval = 30
    private static let pruneMark = ".pruned"
    private static let folderNameLength = 12

    private let tools: URL
    let cache: URL
    private let shipped: String?
    private let now: @Sendable () -> Date

    public init(tools: URL = URL(fileURLWithPath: "/usr/bin", isDirectory: true), cache: URL? = nil, shipped: URL? = nil, now: @escaping @Sendable () -> Date = { Date() }) {
        self.tools = tools
        self.now = now
        let environment = ProcessInfo.processInfo.environment
        self.shipped = (shipped ?? SpotsFolder.core(environment: environment)).map { $0.standardizedFileURL.path + "/" }
        let home = URL(fileURLWithPath: environment["HOME"] ?? NSHomeDirectory(), isDirectory: true)
        self.cache = cache ?? Self.folder(of: SpotsFolder.config(environment: environment, home: home), in: home.appendingPathComponent("Library/Caches/dev.openspot/swift", isDirectory: true))
    }

    static func folder(of config: URL, in root: URL) -> URL {
        let hash = SHA256.hash(data: Data(config.standardizedFileURL.path.utf8)).map { String(format: "%02x", $0) }.joined()
        return root.appendingPathComponent(String(hash.prefix(folderNameLength)), isDirectory: true)
    }

    func runnable(for script: URL, builds: Bool = true) -> URL {
        guard script.pathExtension == Self.sourceExtension, let name = try? Self.name(of: script, with: []) else { return script }
        if isShipped(script), let carried = Self.carried(of: script, named: name) { return carried }
        let program = cache.appendingPathComponent(name)
        if Self.isWhole(program) {
            markUsed(program)
            return program
        }
        guard builds, Self.started.withLock({ $0.insert(program.path).inserted }) else { return script }
        Task.detached(priority: .utility) { [self] in
            if let source = try? Data(contentsOf: script), (try? await cached(source, with: [], at: program)) != nil { Self.started.withLock { _ = $0.remove(program.path) } }
        }
        return script
    }

    func runnable(for spot: Spot, builds: Bool = true) -> URL {
        spot.sources.isEmpty ? runnable(for: spot.url, builds: builds) : spot.url
    }

    func build(of spot: Spot) -> (@Sendable () async throws -> URL)? {
        let (script, names) = (spot.url, spot.sources)
        if !names.isEmpty { return { [self] in try await built(script, with: names) } }
        guard script.pathExtension == Self.sourceExtension, !isShipped(script), let name = try? Self.name(of: script, with: []),
              let carried = Self.carried(of: script, named: name)
        else { return nil }
        let program = cache.appendingPathComponent(name)
        return { [self] in
            if Self.isWhole(program) { return program }
            return await hasTools() ? script : carried
        }
    }

    func built(_ script: URL, with names: [String]) async throws -> URL {
        let name = try Self.name(of: script, with: names)
        let carried = Self.carried(of: script, named: name)
        if isShipped(script), let carried { return carried }
        let program = cache.appendingPathComponent(name)
        if Self.isWhole(program) {
            markUsed(program)
            return program
        }
        let key = "\(tools.path)\n\(program.path)"
        if let fault = Self.faults.withLock({ $0.kept[key] }) { throw SpotError.fault(fault) }
        guard await hasTools() else {
            if let carried { return carried }
            throw SpotError.fault(Self.toolsFault)
        }
        let build = Self.building.withLock { builds in
            if let build = builds[key] { return build }
            let build = Task.detached(priority: .userInitiated) { [self] in
                defer { Self.building.withLock { $0[key] = nil } }
                guard let source = try? Data(contentsOf: script) else { throw SpotError.fault("Openspot cannot find \(script.lastPathComponent).") }
                let more = try Self.sources(named: names, beside: script)
                let place = cache.appendingPathComponent(Self.name(of: source, with: more))
                do {
                    try await cached(source, with: more, at: place)
                } catch let fault as SpotError {
                    if Self.isOfSource(fault.reason, in: more) { Self.keep(fault.reason, of: key) }
                    throw fault
                }
                return place
            }
            builds[key] = build
            return build
        }
        return try await build.value
    }

    func hasTools() async -> Bool {
        let check = Self.toolChecks.withLock { checks in
            if let check = checks[tools.path] { return check }
            if checks.count >= Self.toolsLimit { checks.removeAll() }
            let check = Task.detached { [tools] in await SwiftBuild(tools: tools).hasTools() }
            checks[tools.path] = check
            return check
        }
        return await check.value
    }

    private func isShipped(_ script: URL) -> Bool {
        shipped.map { script.standardizedFileURL.path.hasPrefix($0) } ?? false
    }

    private static func carried(of script: URL, named name: String) -> URL? {
        let carried = path(beside: script.path, hash: name)
        return FileManager.default.fileExists(atPath: carried) ? URL(fileURLWithPath: carried) : nil
    }

    private static func isOfSource(_ reason: String, in more: [SwiftBuild.File]) -> Bool {
        guard reason.hasPrefix("\(fault) "), reason.contains("error:") else { return false }
        let line = reason.dropFirst(fault.count + 1)
        return ([mainName] + more.map { ($0.name as NSString).lastPathComponent }).contains { line.hasPrefix("\($0):") }
    }

    private static func keep(_ reason: String, of key: String) {
        faults.withLock { faults in
            if faults.kept.updateValue(reason, forKey: key) == nil { faults.order.append(key) }
            while faults.order.count > faultLimit { faults.kept[faults.order.removeFirst()] = nil }
        }
    }

    static func paths(named names: [String], beside script: URL) -> [String] {
        let folder = script.deletingLastPathComponent()
        return names.flatMap { name -> [String] in
            let url = folder.appendingPathComponent(name)
            var isFolder: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isFolder), isFolder.boolValue else { return [name] }
            return ((try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []).filter(isSource).sorted().map { "\(name)/\($0)" }
        }
    }

    static func sources(named names: [String], beside script: URL) throws -> [SwiftBuild.File] {
        let folder = script.deletingLastPathComponent()
        return try paths(named: names, beside: script).map { path in
            guard let data = try? Data(contentsOf: folder.appendingPathComponent(path)) else {
                throw SpotError.fault("\(script.lastPathComponent) names the source \(path), which Openspot cannot find.")
            }
            return SwiftBuild.File(name: path, data: data)
        }
    }

    static func name(of script: URL, with names: [String]) throws -> String {
        let folder = script.deletingLastPathComponent()
        let paths = [script.path] + Self.paths(named: names, beside: script).map { folder.appendingPathComponent($0).path }
        let key = paths.joined(separator: "\n")
        let states = paths.map(state)
        let stamp = states.flatMap { $0 }
        if !states.contains([]), let known = Self.names.withLock({ $0[key] }), known.stamp == stamp { return known.name }
        guard let source = try? Data(contentsOf: script) else { throw SpotError.fault("Openspot cannot find \(script.lastPathComponent).") }
        let name = Self.name(of: source, with: try sources(named: names, beside: script))
        Self.names.withLock { kept in
            if kept.count >= nameLimit { kept.removeAll() }
            kept[key] = (stamp, name)
        }
        return name
    }

    private static func state(of path: String) -> [Int] {
        var info = stat()
        guard stat(path, &info) == 0 else { return [] }
        return [Int(info.st_size), Int(info.st_ino), info.st_mtimespec.tv_sec, info.st_mtimespec.tv_nsec]
    }

    static func sources(of script: SpotPackage.File, in files: [SpotPackage.File]) -> [SwiftBuild.File] {
        let folder = (script.path as NSString).deletingLastPathComponent
        let names = script.text.map { SpotHeader(text: $0).block.values(HeaderKey.source) } ?? []
        return names.flatMap { name -> [SwiftBuild.File] in
            let path = folder.isEmpty ? name : "\(folder)/\(name)"
            let inner = files.filter { $0.path == path || ($0.path as NSString).deletingLastPathComponent == path && isSource($0.path) }.sorted { $0.path < $1.path }
            return inner.map { SwiftBuild.File(name: String($0.path.dropFirst(folder.isEmpty ? 0 : folder.count + 1)), data: $0.contents) }
        }
    }

    static func name(of script: Data, with more: [SwiftBuild.File]) -> String {
        var hash = SHA256()
        hash.update(data: script)
        for source in more {
            hash.update(data: Data("\n\(source.name)\n".utf8))
            hash.update(data: source.data)
        }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func isSource(_ path: String) -> Bool {
        (path as NSString).pathExtension == sourceExtension
    }

    public func buildPrograms(under folder: URL) async throws -> [URL] {
        var built: [URL] = []
        let scripts = (FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? [])
            .filter { $0.pathExtension == Self.sourceExtension && !$0.hasDirectoryPath && FileManager.default.isExecutableFile(atPath: $0.path) }
            .sorted { $0.path < $1.path }
        for script in scripts {
            let source = try Data(contentsOf: script)
            let more = try Self.sources(named: SpotHeader(url: script).block.values(HeaderKey.source), beside: script)
            let program = URL(fileURLWithPath: Self.path(beside: script.path, hash: Self.name(of: source, with: more)))
            try await build(source: source, with: more).write(to: program)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: program.path)
            let folder = script.deletingLastPathComponent()
            for old in (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [] where old != program.lastPathComponent && Self.isProgram(old, of: script.lastPathComponent) {
                try FileManager.default.removeItem(at: folder.appendingPathComponent(old))
            }
            built.append(program)
        }
        return built
    }

    @discardableResult
    func prune(keeping scripts: [URL], with sources: [URL: [String]] = [:]) -> Task<Void, Never>? {
        let date = now()
        let mark = cache.appendingPathComponent(Self.pruneMark)
        if let last = Self.changed(mark), date.timeIntervalSince(last) < Self.day { return nil }
        try? FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        guard FileManager.default.createFile(atPath: mark.path, contents: nil, attributes: [.modificationDate: date]) else { return nil }
        let swifts = scripts.filter { $0.pathExtension == Self.sourceExtension }
        return Task.detached(priority: .utility) { [cache] in
            let kept = Set(swifts.compactMap { try? Self.name(of: $0, with: sources[$0] ?? []) })
            let running = Self.runningPrograms()
            let names = (try? FileManager.default.contentsOfDirectory(atPath: cache.path)) ?? []
            for name in names where !name.hasPrefix(".") {
                let program = cache.appendingPathComponent(name)
                let isStale = date.timeIntervalSince(Self.changed(program) ?? date) > Self.unusedDays * Self.day
                guard !kept.contains(name) || isStale, !running.contains(Self.real(program)) else { continue }
                try? FileManager.default.removeItem(at: program)
            }
        }
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

    private static func isWhole(_ program: URL) -> Bool {
        guard FileManager.default.isExecutableFile(atPath: program.path), let handle = try? FileHandle(forReadingFrom: program) else { return false }
        defer { try? handle.close() }
        return (try? handle.read(upToCount: 4)).map { magics.contains(Array($0)) } ?? false
    }

    private func cached(_ source: Data, with more: [SwiftBuild.File], at program: URL) async throws {
        let data = try await SwiftBuild(tools: tools).output(of: Self.files(source, more), flags: Self.flags, kinds: [nil], toolsFault: nil, fault: Self.fault)
        guard Self.magics.contains(Array(data.prefix(4))) else { throw SpotError.fault("swiftc wrote no program.") }
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let placed = cache.appendingPathComponent(".\(program.lastPathComponent)-\(UUID().uuidString)")
        try data.write(to: placed)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: placed.path)
        guard rename(placed.path, program.path) == 0 else {
            try? FileManager.default.removeItem(at: placed)
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }

    private static let fault = "This Swift spot does not compile."
    private static let moreFolder = "more"

    private static func files(_ source: Data, _ more: [SwiftBuild.File]) -> [SwiftBuild.File] {
        [SwiftBuild.File(name: mainName, data: source)] + more.map { SwiftBuild.File(name: "\(moreFolder)/\($0.name)", data: $0.data) }
    }

    static func isProgram(_ url: URL) -> Bool {
        url.pathExtension == programExtension
    }

    static func isProgram(_ path: String, of source: String) -> Bool {
        guard isSource(source) else { return false }
        let stem = (source as NSString).deletingPathExtension + "."
        guard (path as NSString).pathExtension == programExtension, path.hasPrefix(stem) else { return false }
        let hash = (path.dropFirst(stem.count) as NSString).deletingPathExtension
        return hash.count == hashLength && hash.allSatisfy(\.isHexDigit)
    }

    static func path(beside source: String, hash: String) -> String {
        (source as NSString).deletingPathExtension + "." + hash + "." + programExtension
    }

    func build(source: Data, with more: [SwiftBuild.File] = []) async throws -> Data {
        try await SwiftBuild(tools: tools).output(of: Self.files(source, more), flags: Self.flags, kinds: SwiftBuild.kinds, toolsFault: "To share a Swift spot, install the Command Line Tools: xcode-select --install", fault: Self.fault)
    }
}
