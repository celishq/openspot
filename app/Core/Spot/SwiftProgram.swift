import CryptoKit
import Foundation

/// The compiled form of a Swift script, which travels beside its source so that a Mac with no Swift tools can run it, or
/// which a first run builds once into a cache, named by the hash of its source.
public struct SwiftProgram: Sendable {
    static let sourceExtension = "swift"
    private static let programExtension = "program"
    private static let platform = "apple-macos26.0"
    /// The kinds of Mac that a shared build runs on.
    static let kinds = ["arm64", "x86_64"]

    /// The programs that build now, or that failed to build in this run of the app.
    private static let lock = NSLock()
    nonisolated(unsafe) private static var started: Set<String> = []
    /// The first bytes of a program for one kind of Mac, and of a universal one.
    private static let magics: Set<[UInt8]> = [[0xcf, 0xfa, 0xed, 0xfe], [0xca, 0xfe, 0xba, 0xbe]]

    private let tools: URL
    private let cache: URL

    /// `tools` is the folder that holds `xcode-select`, `swiftc` and `lipo`. `cache` holds the program that a first run of
    /// each source builds, by default in the caches of the home, where no spot in Careful mode can write.
    public init(tools: URL = URL(fileURLWithPath: "/usr/bin", isDirectory: true), cache: URL? = nil) {
        self.tools = tools
        let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        self.cache = cache ?? URL(fileURLWithPath: home, isDirectory: true).appendingPathComponent("Library/Caches/dev.openspot/swift", isDirectory: true)
    }

    /// What runs a script: the program beside it, the built program of a Swift source in the cache, or else the file
    /// itself. With `builds`, a Swift source with no whole program in the cache starts its build, and runs itself meanwhile.
    func runnable(for script: URL, builds: Bool = true) -> URL {
        if let program = Self.file(beside: script) { return program }
        guard script.pathExtension == Self.sourceExtension, let source = try? Data(contentsOf: script) else { return script }
        let name = SHA256.hash(data: source).map { String(format: "%02x", $0) }.joined()
        let program = cache.appendingPathComponent(name)
        if Self.isWhole(program) { return program }
        guard builds, Self.lock.withLock({ Self.started.insert(program.path).inserted }) else { return script }
        Task.detached(priority: .utility) { [self] in
            if (try? await cached(source, at: program)) != nil { Self.lock.withLock { _ = Self.started.remove(program.path) } }
        }
        return script
    }

    /// Whether a file is an executable program, which a build cut short or a stray write is not.
    private static func isWhole(_ program: URL) -> Bool {
        guard FileManager.default.isExecutableFile(atPath: program.path), let handle = try? FileHandle(forReadingFrom: program) else { return false }
        defer { try? handle.close() }
        return (try? handle.read(upToCount: 4)).map { magics.contains(Array($0)) } ?? false
    }

    /// Builds a source for this Mac into a work file, and puts it at its place in the cache over any file there.
    private func cached(_ source: Data, at program: URL) async throws {
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let work = cache.appendingPathComponent(".build-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }
        let file = work.appendingPathComponent("main.swift")
        try source.write(to: file)
        let built = work.appendingPathComponent("program")
        _ = try await ScriptProcess.output(url: tool("swiftc"), arguments: ["-O", "-module-name", "Spot", file.path, "-o", built.path])
        guard Self.isWhole(built) else { throw SpotError.fault("swiftc wrote no program.") }
        guard rename(built.path, program.path) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
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
