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

    /// Writes one setting above the tables, and keeps each other line as the person wrote it.
    public func set(_ key: String, to value: String) throws {
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if lines.last == "" { lines.removeLast() }
        let line = "\(key) = \"\(value)\""
        if let index = lines.firstIndex(where: { $0.split(separator: "=", maxSplits: 1).first?.trimmingCharacters(in: .whitespaces) == key }) {
            lines[index] = line
        } else {
            lines.insert(line, at: lines.firstIndex { $0.hasPrefix("[[") } ?? lines.endIndex)
        }
        try save(lines.joined(separator: "\n") + "\n")
    }

    /// Writes the choices for the spots in place of the ones the file holds, and keeps the settings and the keys.
    public func write(_ arrangement: SpotArrangement) throws {
        try writeTables(arrangement, keys: read().keys)
    }

    /// Writes the assigned keys in place of the ones the file holds, and keeps the settings and the choices for the spots.
    public func write(keys: [GlobalKey]) throws {
        try writeTables(read().arrangement, keys: keys)
    }

    /// Writes all the tables under the settings. It throws for a file that it cannot read, so that its tables stay.
    private func writeTables(_ arrangement: SpotArrangement, keys: [GlobalKey]) throws {
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        _ = try TomlDocument(text: text)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var settings = Array(lines.prefix { !$0.hasPrefix("[[") })
        while settings.last == "" { settings.removeLast() }
        let tables = ([arrangement.text] + keys.map(\.text)).filter { !$0.isEmpty }.joined(separator: "\n\n")
        try save((settings + (settings.isEmpty ? [] : [""]) + [tables]).joined(separator: "\n") + "\n")
    }

    private func save(_ text: String) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
}
