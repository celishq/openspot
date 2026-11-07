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

    /// Writes the choices for the spots in place of the ones the file holds, and keeps the settings above them.
    public func write(_ arrangement: SpotArrangement) throws {
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var settings = Array(lines.prefix { !$0.hasPrefix("[[") })
        while settings.last == "" { settings.removeLast() }
        try save((settings + (settings.isEmpty ? [] : [""]) + [arrangement.text]).joined(separator: "\n") + "\n")
    }

    /// Makes the file, with each default, when it does not exist.
    public func begin() throws {
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try save("")
    }

    /// Turns a core spot on or off, and keeps each other choice.
    public func turn(_ id: String, on isOn: Bool) throws {
        var arrangement = read().arrangement
        arrangement.set(isEnabled: isOn, of: id)
        try write(arrangement)
    }

    private func save(_ text: String) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
}
