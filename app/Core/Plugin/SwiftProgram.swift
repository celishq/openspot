import Foundation

/// The compiled form of a Swift script, which travels beside its source so that a Mac with no Swift tools can run it.
public struct SwiftProgram: Sendable {
    static let sourceExtension = "swift"
    private static let programExtension = "program"
    private static let platform = "apple-macos26.0"
    /// The kinds of Mac that a shared build runs on.
    static let kinds = ["arm64", "x86_64"]

    private let tools: URL

    /// `tools` is the folder that holds `xcode-select`, `swiftc` and `lipo`.
    public init(tools: URL = URL(fileURLWithPath: "/usr/bin", isDirectory: true)) {
        self.tools = tools
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
            throw PluginError.fault("To share a Swift spot, install the Command Line Tools: xcode-select --install")
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
                throw PluginError.fault("This Swift spot does not compile. \((error as? PluginError)?.reason ?? String(describing: error))")
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
