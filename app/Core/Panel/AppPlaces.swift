import Foundation

public struct AppPlaces {
    public let environment: [String: String]
    public let home: URL
    public let defaults: UserDefaults
    public let trash: (URL) throws -> URL
    public let defaultConfig: URL?

    public init(
        environment: [String: String],
        home: URL,
        defaults: UserDefaults,
        trash: @escaping (URL) throws -> URL = AppPlaces.systemTrash,
        defaultConfig: URL? = Bundle.main.url(forResource: "defaults", withExtension: "toml")
    ) {
        self.environment = environment
        self.home = home
        self.defaults = defaults
        self.trash = trash
        self.defaultConfig = defaultConfig
    }

    public static func systemTrash(_ url: URL) throws -> URL {
        var place: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &place)
        return (place as URL?) ?? url
    }

    public static var standard: AppPlaces {
        AppPlaces(environment: ProcessInfo.processInfo.environment, home: FileManager.default.homeDirectoryForCurrentUser, defaults: .standard)
    }

    public var config: ConfigFile {
        .standard(environment: environment, home: home)
    }

    public var defaultArrangement: SpotArrangement {
        guard let defaultConfig, let text = try? String(contentsOf: defaultConfig, encoding: .utf8) else { return SpotArrangement() }
        return Config(text: text).arrangement
    }

    public func folder(_ config: Config) -> SpotsFolder {
        .standard(environment: environment, home: home, enabled: config.arrangement.enabled, disabled: config.arrangement.disabled)
    }

    public var folder: SpotsFolder {
        folder(config.read())
    }

    public var account: AccountStore {
        .standard(environment: environment, home: home)
    }

    public var store: URL {
        SpotStore.url(environment: environment, home: home)
    }

    public var log: CallLog {
        CallLog(folder: SpotsFolder.config(environment: environment, home: home).appendingPathComponent("logs", isDirectory: true))
    }

    public var stats: URL {
        SpotsFolder.config(environment: environment, home: home).appendingPathComponent("stats", isDirectory: true)
    }

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
