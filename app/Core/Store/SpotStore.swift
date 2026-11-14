import Foundation

/// The store: each spot that comes with the app, each spot of the spots folder, and each package in the store's folder that
/// the spots folder lacks, by its store ID. Each says where it comes from and whether the person has it, and a spot of
/// their own says whether the store holds it as it is. Get turns a spot on, or adds its package to the spots folder.
public struct SpotStore: Sendable {
    /// One spot of the store.
    public struct Item: Sendable {
        public let id: String
        public let spot: Spot
        public let origin: SpotOrigin
        public let isAdded: Bool
        /// The size of its card on the grid: the person's choice, or else its own.
        public let size: SpotSize
        /// Whether the store holds a spot of the person's own as it is, or nil when it holds none.
        public let publication: SpotPublication?

        /// The folder of a package of the store, which a get adds to the spots folder.
        public var package: URL? {
            origin == .store ? spot.url.deletingLastPathComponent() : nil
        }
    }

    /// The folder of the packages that the person published.
    public let url: URL
    let folder: SpotsFolder
    let arrangement: SpotArrangement

    public init(url: URL, folder: SpotsFolder, arrangement: SpotArrangement) {
        self.url = url
        self.folder = folder
        self.arrangement = arrangement
    }

    /// The store's folder in the config folder.
    public static func url(environment: [String: String], home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        SpotsFolder.config(environment: environment, home: home).appendingPathComponent("store", isDirectory: true)
    }

    /// The ID by which the store names a spot of the app or of the spots folder: its core ID, or the ID of its file.
    public static func id(of spot: Spot, in folder: SpotsFolder) -> String {
        folder.fileID(of: spot)
    }

    /// Each spot of the store, by name, with whether the store holds each spot of the person's own as it is.
    public var items: [Item] {
        items(publications: true)
    }

    /// Each spot of the store, by name. With no publications it reads no package, which a hash of each file would cost.
    public func items(publications reads: Bool) -> [Item] {
        let own = (try? SpotsFolder(url: folder.url).keptScan()) ?? ScanResult(files: [], refused: [])
        let ownIDs = Set(own.files.map(\.id))
        let publications = reads ? Self.publications(of: own, in: url) : [:]
        let enabled = arrangement.enabled.union(folder.enabled)
        let disabled = arrangement.disabled.union(folder.disabled)
        let core = folder.keptCoreChoices().filter { !ownIDs.contains(SpotsFolder.coreID(of: $0)) }.map { spot in
            item(spot, id: SpotsFolder.coreID(of: spot), origin: .core, isAdded: enabled.contains(SpotsFolder.coreID(of: spot)))
        }
        let mine = own.files.compactMap { file in
            file.spots.first.map { item($0, id: file.id, origin: .mine, isAdded: !disabled.contains(file.id), publication: publications[$0.id]) }
        }
        let stored = ((try? SpotsFolder(url: url).scan())?.files ?? []).filter { !ownIDs.contains($0.id) }.compactMap { file in
            file.spots.first.map { item($0, id: file.id, origin: .store, isAdded: false) }
        }
        return (core + mine + stored).sorted { $0.spot.name.localizedCaseInsensitiveCompare($1.spot.name) == .orderedAscending }
    }

    public func item(_ id: String) -> Item? {
        items(publications: false).first { $0.id == id }
    }

    private func item(_ spot: Spot, id: String, origin: SpotOrigin, isAdded: Bool, publication: SpotPublication? = nil) -> Item {
        Item(id: id, spot: spot, origin: origin, isAdded: isAdded, size: arrangement.size(of: id) ?? spot.size, publication: publication)
    }

    /// Turns a spot that comes with the app or one of the person's own on in this arrangement. A package needs `add`.
    public func turnOn(_ item: Item, in arrangement: inout SpotArrangement) {
        guard item.origin != .store else { return }
        arrangement.set(isEnabled: true, of: item.id)
    }

    /// Adds the package of a spot of the store to the spots folder, which loads it when the folder changes.
    public func add(_ item: Item, environment: [String: String]) async throws {
        guard let package = item.package else { return }
        _ = try await SpotLock.standard(environment: environment).add(SpotSource(text: package.path, place: package), to: folder.url, isConfirmed: false)
    }

    /// Gets a spot of the store: turns it on in the config, or adds its package. A spot that the person has stays as it is.
    public func get(_ id: String, config: ConfigFile, environment: [String: String]) async throws -> Item {
        guard let item = item(id) else {
            throw SpotError.failed(1, "`\(id)` is not a spot of the store. Run `openspot store list` to see each one.")
        }
        guard !item.isAdded else { return item }
        if item.origin == .store { try await add(item, environment: environment) } else {
            try config.turn(item.id, on: true)
        }
        return item
    }

    /// Whether the store holds each spot of the spots folder as its files are now, by the spot's ID.
    static func publications(of scan: ScanResult, in store: URL) -> [String: SpotPublication] {
        var result: [String: SpotPublication] = [:]
        for spot in scan.spots where FileManager.default.fileExists(atPath: store.appendingPathComponent(SpotID(file: spot.url).folderName).path) {
            guard let shared = try? SpotPackage(sharing: spot, from: scan) else { continue }
            result[spot.id] = publication(of: shared, in: store)
        }
        return result
    }

    /// Whether the store holds a copy of a spot's own spot folder with the files that a person writes as they are now, or
    /// older ones, or nil when it holds none. The programs and the views that a publish builds, and the release log, do not count.
    static func publication(of spot: SpotPackage, in store: URL) -> SpotPublication? {
        guard let root = spot.roots.first, let stored = try? SpotPackage(contentsOf: store.appendingPathComponent(root)) else { return nil }
        return stored.manifest(of: root).written == spot.manifest(of: root).written ? .current : .changed
    }

    /// Each spot as JSON, for `openspot store list`.
    func json() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(items.map(Printed.init)), as: UTF8.self) + "\n"
    }

    /// Each spot as a `spot` block, for `openspot store list --frame` (protocol: The openspot command).
    func frame() -> String {
        items.map(Printed.init).map { printed in
            let pairs: [(String, String?)] = [
                ("spot", printed.id), ("name", printed.name), ("icon", printed.icon), ("detail", printed.detail), ("size", printed.size),
                ("origin", printed.origin), ("added", String(printed.added)), ("published", printed.published), ("path", printed.path)
            ]
            return TextBlock(fields: pairs.compactMap { key, value in value.map { TextBlock.Field(key: key, value: $0) } }).text + "\n"
        }.joined()
    }

    /// The words that `openspot store list` prints for one spot.
    private struct Printed: Encodable {
        let id, name, icon, size, origin: String
        let detail, published, path: String?
        let added: Bool

        init(_ item: Item) {
            id = item.id
            name = item.spot.name
            icon = item.spot.image ?? item.spot.file ?? item.spot.glyph ?? item.spot.symbol
            detail = item.spot.subtitle
            size = item.size.name
            origin = item.origin.rawValue
            added = item.isAdded
            published = item.publication?.rawValue
            path = item.package?.path
        }
    }
}
