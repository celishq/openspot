import Foundation

/// Where the app keeps its plugins, its config and the recent rows of each list. A test points it at a folder of its own.
public struct SpotFiles {
    public let environment: [String: String]
    public let home: URL
    public let defaults: UserDefaults

    public init(environment: [String: String], home: URL, defaults: UserDefaults) {
        self.environment = environment
        self.home = home
        self.defaults = defaults
    }

    public static var standard: SpotFiles {
        SpotFiles(environment: ProcessInfo.processInfo.environment, home: FileManager.default.homeDirectoryForCurrentUser, defaults: .standard)
    }

    public var config: ConfigFile {
        .standard(environment: environment, home: home)
    }

    /// The plugin folder, with the core spots that this config turns on.
    public func folder(_ config: Config) -> PluginFolder {
        .standard(environment: environment, home: home, enabled: config.arrangement.enabled)
    }

    /// The plugin folder, with the core spots that the config file turns on now.
    public var folder: PluginFolder {
        folder(config.read())
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
