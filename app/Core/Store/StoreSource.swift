import Foundation

public enum StoreSource: Hashable, Sendable {
    case builtIn(URL)
    case folder(URL)
    case file(URL, hash: String)

    public init(url: URL) {
        self = .folder(Self.standard(url))
    }

    public init(file url: URL) throws {
        let package = try SpotPackage(contentsOf: url)
        let hash = SpotDigest(package.files).hash
        let staged = Self.staged(hash)
        if !FileManager.default.fileExists(atPath: staged.path) {
            let work = staged.deletingLastPathComponent().appendingPathComponent("\(hash)-\(UUID().uuidString)", isDirectory: true)
            try package.add(to: work)
            do {
                try FileManager.default.moveItem(at: work, to: staged)
            } catch {
                try? FileManager.default.removeItem(at: work)
                if !FileManager.default.fileExists(atPath: staged.path) { throw error }
            }
        }
        self = .file(URL(fileURLWithPath: url.standardizedFileURL.path), hash: hash)
    }

    private static func staged(_ hash: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("openspot-opened/\(hash)", isDirectory: true)
    }

    private static func standard(_ url: URL) -> URL {
        URL(fileURLWithPath: url.standardizedFileURL.path, isDirectory: true)
    }

    public var url: URL {
        switch self {
        case .builtIn(let url), .folder(let url), .file(let url, _): url
        }
    }

    private var folder: URL {
        switch self {
        case .builtIn(let url), .folder(let url): url
        case .file(_, let hash): Self.staged(hash)
        }
    }

    public var symbol: String {
        switch self {
        case .builtIn: "sparkles"
        case .folder: "folder"
        case .file: "doc"
        }
    }

    public var canRemove: Bool {
        if case .folder = self { return true }
        return false
    }

    public var name: String {
        switch self {
        case .builtIn: "Openspot"
        case .folder(let url), .file(let url, _): url.lastPathComponent
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
        (try? SpotsFolder(url: folder).scan())?.files ?? []
    }

    func origin(of spot: URL) -> SpotSource {
        switch self {
        case .builtIn: .builtIn(spot)
        case .folder: .folder(spot)
        case .file(let url, _): .file(url)
        }
    }

    func readPackage() throws -> SpotPackage? {
        guard case .file = self else { return nil }
        let roots = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { !$0.hasPrefix(".") }
        return try SpotPackage(paths: roots, in: folder)
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
