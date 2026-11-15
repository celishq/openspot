import Foundation

struct SwiftBuild: Sendable {
    struct File: Equatable, Sendable {
        let name: String
        let data: Data
    }

    static let kinds = ["arm64", "x86_64"]
    static let platform = "apple-macos26.0"

    let tools: URL

    func output(of files: [File], flags: [String], kinds: [String?], toolsFault: String?, fault: String) async throws -> Data {
        if let toolsFault, (try? await run("xcode-select", ["-p"])) == nil { throw SpotError.fault(toolsFault) }
        let place = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-build-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: place) }
        let sources = place.appendingPathComponent("sources", isDirectory: true)
        var paths: [String] = []
        for file in files {
            let url = sources.appendingPathComponent(file.name)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try file.data.write(to: url)
            paths.append(url.path)
        }
        var parts: [String] = []
        for kind in kinds {
            let part = place.appendingPathComponent(kind ?? "host").path
            parts.append(part)
            do {
                try await run("swiftc", flags + (kind.map { ["-target", "\($0)-\(Self.platform)"] } ?? []) + paths + ["-o", part])
            } catch let error as SpotError {
                throw SpotError.fault("\(fault) \(error.reason)")
            }
        }
        guard parts.count > 1 else { return try Data(contentsOf: URL(fileURLWithPath: parts[0])) }
        let joined = place.appendingPathComponent("joined")
        try await run("lipo", ["-create"] + parts + ["-output", joined.path])
        return try Data(contentsOf: joined)
    }

    private func run(_ name: String, _ arguments: [String]) async throws {
        let process = ScriptProcess(url: tools.appendingPathComponent(name), arguments: arguments)
        do {
            for try await _ in process.start() {}
        } catch SpotError.failed {
            let lines = process.errors.split(separator: "\n").map(String.init)
            let line = lines.first { $0.contains("error:") } ?? lines.last ?? "\(name) failed."
            throw SpotError.fault(Self.withoutFolders(line))
        }
    }

    private static func withoutFolders(_ line: String) -> String {
        guard line.hasPrefix("/"), let colon = line.firstIndex(of: ":") else { return line }
        let path = line[..<colon]
        return String(line[(path.lastIndex(of: "/").map { line.index(after: $0) } ?? path.startIndex)...])
    }
}
