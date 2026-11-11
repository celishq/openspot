import Foundation

/// Where the app keeps its plugins, its config and the recent rows of each list. A test points it at a folder of its own.
public struct SpotFiles {
    public let environment: [String: String]
    public let home: URL
    public let defaults: UserDefaults
    /// Moves a file to the Trash, and returns where it went.
    public let trash: (URL) throws -> URL
    /// The config that ships with the app, whose choices for the core spots, such as their letters, count until the
    /// person's config makes its own.
    public let defaultConfig: URL?

    public init(
        environment: [String: String],
        home: URL,
        defaults: UserDefaults,
        trash: @escaping (URL) throws -> URL = SpotFiles.systemTrash,
        defaultConfig: URL? = Bundle.main.url(forResource: "defaults", withExtension: "toml")
    ) {
        self.environment = environment
        self.home = home
        self.defaults = defaults
        self.trash = trash
        self.defaultConfig = defaultConfig
    }

    /// Moves a file to the Trash of the Mac.
    public static func systemTrash(_ url: URL) throws -> URL {
        var place: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &place)
        return (place as URL?) ?? url
    }

    public static var standard: SpotFiles {
        SpotFiles(environment: ProcessInfo.processInfo.environment, home: FileManager.default.homeDirectoryForCurrentUser, defaults: .standard)
    }

    public var config: ConfigFile {
        .standard(environment: environment, home: home)
    }

    /// The choices of the config that ships with the app. A file that is missing or that it cannot read gives none.
    public var defaultArrangement: SpotArrangement {
        guard let defaultConfig, let text = try? String(contentsOf: defaultConfig, encoding: .utf8) else { return SpotArrangement() }
        return Config(text: text).arrangement
    }

    /// The plugin folder, with the core spots that this config turns on.
    public func folder(_ config: Config) -> PluginFolder {
        .standard(environment: environment, home: home, enabled: config.arrangement.enabled)
    }

    /// The plugin folder, with the core spots that the config file turns on now.
    public var folder: PluginFolder {
        folder(config.read())
    }

    /// The record of the calls of each spot, beside the plugins folder.
    public var log: CallLog {
        CallLog(folder: PluginFolder.config(environment: environment, home: home).appendingPathComponent("logs", isDirectory: true))
    }

    /// The rows that a person picked last in a list, the newest first.
    public func recent(of id: String) -> [String] {
        defaults.stringArray(forKey: Self.recentKey(id)) ?? []
    }

    public func remember(_ rows: [String], of id: String) {
        defaults.set(rows, forKey: Self.recentKey(id))
    }

    private static func recentKey(_ id: String) -> String {
        "recent.\(id)"
    }
}
