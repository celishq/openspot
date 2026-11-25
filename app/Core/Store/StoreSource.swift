import Foundation

public enum StoreSource: Hashable, Sendable {
    case builtIn(URL)
    case folder(URL)

    public init(url: URL) {
        self = .folder(Self.standard(url))
    }

    private static func standard(_ url: URL) -> URL {
        URL(fileURLWithPath: url.standardizedFileURL.path, isDirectory: true)
    }

    public var url: URL {
        switch self {
        case .builtIn(let url), .folder(let url): url
        }
    }

    public var name: String {
        switch self {
        case .builtIn: "Openspot"
        case .folder(let url): url.lastPathComponent
        }
    }

    public var isBuiltIn: Bool {
        if case .builtIn = self { return true }
        return false
    }

    public static func builtIn(environment: [String: String]) -> StoreSource? {
        let url = environment["OPENSPOT_EXAMPLES"].flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0) }
            ?? Bundle.main.resourceURL?.appendingPathComponent("examples", isDirectory: true)
        return url.map { .builtIn(standard($0)) }
    }

    public static func all(builtIn: StoreSource?, config: Config) -> [StoreSource] {
        [builtIn].compactMap { $0 } + config.stores
    }

    var table: ConfigDocument.Table {
        ConfigDocument.Table("stores", [("path", .string(url.path))])
    }

    public func exists() -> Bool {
        var isFolder: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isFolder) && isFolder.boolValue
    }

    public func spots() -> [SpotFile] {
        (try? SpotsFolder(url: url).scan())?.files ?? []
    }

    public func fetch(_ id: String) -> URL? {
        spots().first { $0.id == id }?.spots.first?.url.deletingLastPathComponent()
    }

    public static func add(_ url: URL, to config: ConfigFile) throws -> String {
        let source = StoreSource(url: url)
        guard source.exists() else { throw SpotError.failed(1, "Openspot cannot find \(source.url.path).") }
        let count = source.spots().count
        guard count > 0 else {
            throw SpotError.failed(1, "\(source.name) has no spot folder, so it cannot be a store. Pick a folder that holds a folder such as weather.spot.")
        }
        _ = try config.change { $0.add(store: source) }
        return "Added the store \(source.name) with \(count) \(count == 1 ? "spot" : "spots").\n"
    }

    public static func remove(_ url: URL, from config: ConfigFile) throws -> String {
        let source = StoreSource(url: url)
        guard config.read().stores.contains(source) else {
            throw SpotError.failed(1, "\(source.url.path) is not a store. Run `openspot store folders` to see each one.")
        }
        _ = try config.change { $0.remove(store: source) }
        return "Removed the store \(source.name).\n"
    }
}
