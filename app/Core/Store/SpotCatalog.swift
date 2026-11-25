import Foundation

public struct SpotCatalog: Sendable {
    public struct Item: Sendable {
        public let id: String
        public let spot: Spot
        public let isAdded: Bool
        public let size: SpotSize
        public let hasSample: Bool
        public let store: StoreSource?
        public let version: SpotVersion?
        public let copy: SpotUpdate.State?
        let isCore: Bool

        public var origin: SpotOrigin {
            store != nil ? .store : isCore ? .core : .mine
        }

        public var runsSample: Bool {
            store == nil
        }

        public var step: String {
            guard isAdded else { return "get" }
            return "added"
        }

        public var package: URL? {
            store == nil ? nil : spot.url.deletingLastPathComponent()
        }
    }

    let folder: SpotsFolder
    let arrangement: SpotChoices
    let stores: [StoreSource]
    let lock: SpotLock?

    public init(folder: SpotsFolder, arrangement: SpotChoices, stores: [StoreSource], lock: SpotLock? = nil) {
        self.folder = folder
        self.arrangement = arrangement
        self.stores = stores
        self.lock = lock
    }

    public init(places: AppPlaces, config: Config, stores: [StoreSource]) {
        self.init(folder: places.spots, arrangement: config.arrangement, stores: stores, lock: places.lock)
    }

    public static func id(of spot: Spot, in folder: SpotsFolder) -> String {
        folder.fileID(of: spot)
    }

    public var items: [Item] {
        let own = (try? folder.scanOwn()) ?? ScanResult(files: [], refused: [])
        let ownIDs = Set(own.files.map(\.id))
        let entries = (try? lock?.entries()) ?? []
        let core = folder.coreChoices().filter { !ownIDs.contains(SpotsFolder.coreID(of: $0)) }.map { spot in
            item(spot, id: SpotsFolder.coreID(of: spot), isAdded: true, isCore: true)
        }
        let mine = own.files.compactMap { file in
            file.spots.first.map { spot in
                let copy = lock.flatMap { lock in entries.first { $0.holds(file.id) }.flatMap { SpotUpdate.state(of: $0, in: folder.url, lock: lock) } }
                return item(spot, id: file.id, isAdded: true, version: copy?.version, copy: copy?.state)
            }
        }
        let stored = stores.flatMap { store in
            store.spots().filter { !ownIDs.contains($0.id) }.compactMap { file in
                file.spots.first.map { spot in
                    item(spot, id: file.id, isAdded: false, store: store, version: lock == nil ? nil : try? SpotVersion(of: spot.url.deletingLastPathComponent()))
                }
            }
        }
        var seen = Set<String>()
        return (core + mine + stored).filter { seen.insert($0.id).inserted }.sorted { $0.spot.comesBefore($1.spot) }
    }

    public func item(_ id: String) -> Item? {
        items.first { $0.id == id }
    }

    private func item(
        _ spot: Spot, id: String, isAdded: Bool, isCore: Bool = false, store: StoreSource? = nil, version: SpotVersion? = nil,
        copy: SpotUpdate.State? = nil
    ) -> Item {
        Item(
            id: id, spot: spot, isAdded: isAdded, size: arrangement.size(of: id) ?? spot.size,
            hasSample: SpotSample.exists(for: spot, runsScript: store == nil), store: store, version: version, copy: copy, isCore: isCore
        )
    }

    public func install(_ id: String, in places: AppPlaces, from source: StoreSource? = nil) throws -> SpotInstall? {
        if item(id)?.isCore == true { return nil }
        let found = (source.map { [$0] } ?? stores).lazy.compactMap { source in
            source.spots().first { $0.id == id }?.spots.first.flatMap { spot in source.fetch(id).map { (name: spot.name, folder: $0, source: source) } }
        }.first
        guard let found else {
            guard item(id) != nil else {
                throw SpotError.failed(1, "`\(id)` is not a spot of the store. Run `openspot store list` to see each one.")
            }
            return nil
        }
        let expecting = try found.source.readPackage()
        return SpotInstall(
            id: id, name: found.name, source: found.folder, origin: found.source.origin(of: found.folder), expecting: expecting,
            reviewed: expecting == nil ? try SpotVersion.hash(of: found.folder) : nil, spots: folder.url, core: folder.core, lock: places.lock, config: places.config, trash: places.trash
        )
    }

    func text(_ form: PrintForm, now: Date = RunClock().now()) throws -> String {
        try form.text(of: items.map { Printed($0, now: now) })
    }

    private struct Printed: PrintedRecord {
        let id, name, icon, size, origin, step: String
        let detail, path, store, updated, copy: String?
        let readme: [String]
        let added, sample: Bool

        var blocks: [[(String, String?)]] {
            [[
                ("item", id), ("title", name), ("icon", icon), ("detail", detail), ("size", size), ("origin", origin), ("added", String(added)), ("step", step),
                ("path", path), ("store", store), ("sample", sample ? "true" : nil), ("updated", updated), ("copy", copy)
            ] + readme.map { ("readme", $0) }]
        }

        init(_ item: Item, now: Date) {
            id = item.id
            name = item.spot.name
            icon = item.spot.picture
            detail = item.spot.subtitle
            size = item.size.name
            origin = item.origin.rawValue
            added = item.isAdded
            step = item.step
            sample = item.hasSample
            path = item.package?.path
            store = item.store?.url.path
            readme = SpotReadme.lines(at: SpotReadme.url(beside: item.spot.url))
            updated = item.version?.day(now: now)
            copy = item.copy == .current ? nil : item.copy?.rawValue
        }
    }
}
