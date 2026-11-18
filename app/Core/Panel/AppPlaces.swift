import Foundation

public struct AppPlaces: Sendable {
    public let environment: [String: String]
    public let home: URL
    nonisolated(unsafe) public let defaults: UserDefaults
    public let trash: @Sendable (URL) throws -> URL
    public let kinds: @Sendable ([String]) -> FileKinds
    public let defaultConfig: URL?
    public let account: AccountStore
    public let secrets: SecretStore
    public let config: ConfigFile
    public let spots: SpotsFolder
    public let store: URL
    public let examples: Store?
    public let lock: SpotLock
    let configFolder: URL

    public init(
        environment: [String: String],
        home: URL,
        defaults: UserDefaults,
        trash: @escaping @Sendable (URL) throws -> URL = AppPlaces.systemTrash,
        kinds: @escaping @Sendable ([String]) -> FileKinds = { FileKinds.Disk().read($0) },
        defaultConfig: URL? = Bundle.main.url(forResource: "defaults", withExtension: "toml"),
        disk: any ConfigDisk = LocalDisk()
    ) {
        self.environment = environment
        self.home = home
        self.defaults = defaults
        self.trash = trash
        self.kinds = kinds
        self.defaultConfig = defaultConfig
        let own = SpotsFolder.ownConfig(environment: environment)
        configFolder = own ?? SpotsFolder.defaultConfig(home: home)
        account = .standard(own: own)
        secrets = .standard(own: own)
        config = .standard(in: configFolder, disk: disk)
        spots = .standard(environment: environment, home: home, enabled: [], disabled: [])
        store = SpotCatalog.url(environment: environment, home: home)
        examples = Store.builtIn(environment: environment)
        lock = .standard(environment: environment, home: home)
    }

    public static func systemTrash(_ url: URL) throws -> URL {
        var place: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &place)
        return (place as URL?) ?? url
    }

    public static var standard: AppPlaces {
        AppPlaces(environment: ProcessInfo.processInfo.environment, home: FileManager.default.homeDirectoryForCurrentUser, defaults: .standard)
    }

    public func readDefaultArrangement() -> SpotArrangement {
        guard let defaultConfig, let text = try? String(contentsOf: defaultConfig, encoding: .utf8) else { return SpotArrangement() }
        return Config(text: text).arrangement
    }

    public func folder(_ config: Config) -> SpotsFolder {
        SpotsFolder(url: spots.url, core: spots.core, enabled: config.arrangement.enabled, disabled: config.arrangement.disabled, wrapsLooseFiles: true)
    }

    public func readSpots() -> SpotsFolder {
        folder(config.read())
    }

    public var log: CallLog {
        CallLog(folder: configFolder.appendingPathComponent("logs", isDirectory: true))
    }

    public var stats: URL {
        configFolder.appendingPathComponent("stats", isDirectory: true)
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
