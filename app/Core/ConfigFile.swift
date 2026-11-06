import Foundation

/// The file of settings, which a person can also write by hand.
public struct ConfigFile: Equatable, Sendable {
    public let url: URL

    public static func standard(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> ConfigFile {
        ConfigFile(url: PluginFolder.config(environment: environment, home: home).appendingPathComponent("config.toml"))
    }

    /// What the file asks for. With no file, that is each default.
    public func read() -> Config {
        Config(text: (try? String(contentsOf: url, encoding: .utf8)) ?? "")
    }

    /// Writes one setting, and keeps each other line as the person wrote it.
    public func set(_ key: String, to value: String) throws {
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if lines.last == "" { lines.removeLast() }
        let line = "\(key) = \"\(value)\""
        if let index = lines.firstIndex(where: { $0.split(separator: "=", maxSplits: 1).first?.trimmingCharacters(in: .whitespaces) == key }) {
            lines[index] = line
        } else {
            lines.append(line)
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}
