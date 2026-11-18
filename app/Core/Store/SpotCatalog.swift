import Foundation

public struct SpotCatalog: Sendable {
    public struct Item: Sendable {
        public let id: String
        public let spot: Spot
        public let isAdded: Bool
        public let size: SpotSize
        public let publication: SpotPublication?
        public let hasSample: Bool
        public let store: Store?
        let isCore: Bool

        public var origin: SpotOrigin {
            store != nil ? .store : isCore ? .core : .mine
        }

        public var runsSample: Bool {
            store == nil
        }

        public var step: String {
            guard isAdded else { return "get" }
            return origin == .mine && publication != .current ? "publish" : "added"
        }

        public var package: URL? {
            store == nil ? nil : spot.url.deletingLastPathComponent()
        }
    }

    let published: URL
    let folder: SpotsFolder
    let arrangement: SpotArrangement
    let stores: [Store]

    public init(published: URL, folder: SpotsFolder, arrangement: SpotArrangement, stores: [Store]) {
        self.published = published
        self.folder = folder
        self.arrangement = arrangement
        self.stores = stores
    }

    public static func url(environment: [String: String], home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        SpotsFolder.config(environment: environment, home: home).appendingPathComponent("store", isDirectory: true)
    }

    public static func id(of spot: Spot, in folder: SpotsFolder) -> String {
        folder.fileID(of: spot)
    }

    public var items: [Item] {
        items(publications: true)
    }

    public func items(publications reads: Bool) -> [Item] {
        let own = (try? SpotsFolder(url: folder.url).scan()) ?? ScanResult(files: [], refused: [])
        let ownIDs = Set(own.files.map(\.id))
        let publications = reads ? Self.publications(of: own, in: published) : [:]
        let enabled = arrangement.enabled.union(folder.enabled)
        let disabled = arrangement.disabled.union(folder.disabled)
        let core = folder.coreChoices().filter { !ownIDs.contains(SpotsFolder.coreID(of: $0)) }.map { spot in
            item(spot, id: SpotsFolder.coreID(of: spot), isAdded: enabled.contains(SpotsFolder.coreID(of: spot)), isCore: true)
        }
        let mine = own.files.compactMap { file in
            file.spots.first.map { item($0, id: file.id, isAdded: !disabled.contains(file.id), publication: publications[$0.id]) }
        }
        let stored = stores.flatMap { store in
            ((try? SpotsFolder(url: store.url).scan())?.files ?? []).filter { !ownIDs.contains($0.id) }.compactMap { file in
                file.spots.first.map { item($0, id: file.id, isAdded: false, store: store) }
            }
        }
        var seen = Set<String>()
        return (core + mine + stored).filter { seen.insert($0.id).inserted }.sorted { $0.spot.name.localizedCaseInsensitiveCompare($1.spot.name) == .orderedAscending }
    }

    public func item(_ id: String) -> Item? {
        items(publications: false).first { $0.id == id }
    }

    private func item(_ spot: Spot, id: String, isAdded: Bool, isCore: Bool = false, publication: SpotPublication? = nil, store: Store? = nil) -> Item {
        Item(
            id: id, spot: spot, isAdded: isAdded, size: arrangement.size(of: id) ?? spot.size, publication: publication,
            hasSample: SpotSample.exists(for: spot, runsScript: store == nil), store: store, isCore: isCore
        )
    }

    public func add(_ item: Item, lock: SpotLock) async throws {
        guard let package = item.package else { return }
        _ = try await lock.add(SpotSource(text: package.path, place: package), to: folder.url, isConfirmed: false)
    }

    public func get(_ id: String, config: ConfigFile, lock: SpotLock) async throws -> Item {
        guard let item = item(id) else {
            throw SpotError.failed(1, "`\(id)` is not a spot of the store. Run `openspot store list` to see each one.")
        }
        guard !item.isAdded else { return item }
        if item.store != nil { try await add(item, lock: lock) } else {
            try config.change { $0.arrangement.set(isEnabled: true, of: item.id) }
        }
        return item
    }

    static func publications(of scan: ScanResult, in store: URL) -> [String: SpotPublication] {
        var result: [String: SpotPublication] = [:]
        for spot in scan.spots where FileManager.default.fileExists(atPath: store.appendingPathComponent(SpotID(file: spot.url).folderName).path) {
            guard let shared = try? SpotPackage(sharing: spot, from: scan) else { continue }
            result[spot.id] = publication(of: shared, in: store)
        }
        return result
    }

    static func publication(of spot: SpotPackage, in store: URL) -> SpotPublication? {
        guard let root = spot.roots.first, let stored = try? SpotPackage(contentsOf: store.appendingPathComponent(root)) else { return nil }
        return stored.manifest(of: root).written == spot.manifest(of: root).written ? .current : .changed
    }

    func text(_ form: PrintForm) throws -> String {
        try form.text(of: items.map(Printed.init))
    }

    private struct Printed: PrintedRecord {
        let id, name, icon, size, origin, step: String
        let detail, published, path, store: String?
        let readme: [String]
        let added, sample: Bool

        var blocks: [[(String, String?)]] {
            [[
                ("text", id), ("title", name), ("icon", icon), ("detail", detail), ("size", size), ("origin", origin), ("added", String(added)), ("step", step),
                ("published", published), ("path", path), ("store", store), ("sample", sample ? "true" : nil)
            ] + readme.map { ("readme", $0) }]
        }

        init(_ item: Item) {
            id = item.id
            name = item.spot.name
            icon = item.spot.image ?? item.spot.file ?? item.spot.glyph ?? item.spot.symbol
            detail = item.spot.subtitle
            size = item.size.name
            origin = item.origin.rawValue
            added = item.isAdded
            step = item.step
            sample = item.hasSample
            published = item.publication?.rawValue
            path = item.package?.path
            store = item.store?.url.path
            readme = SpotReadme.lines(at: SpotReadme.url(beside: item.spot.url))
        }
    }
}
