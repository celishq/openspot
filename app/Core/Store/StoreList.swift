import Foundation

/// The spots that `openspot store list` prints: each spot that comes with the app, each spot of the spots folder, and each
/// package of the store that the spots folder lacks, by name. Each says whether the person has it, and a spot of their own
/// says whether the store holds it as it is.
struct StoreList {
    /// One spot of the store.
    struct Item: Encodable, Equatable {
        let id: String
        let name: String
        let icon: String
        let detail: String?
        let size: String
        /// `core`, `mine` or `store`.
        let origin: String
        let added: Bool
        /// `current` or `changed` for a spot of the spots folder that the store holds, or nil.
        let published: String?
        /// The folder of a package of the store, which `openspot spot add` takes.
        let path: String?
    }

    let folder: SpotsFolder
    let config: Config
    let store: URL

    var items: [Item] {
        let own = (try? SpotsFolder(url: folder.url).keptScan()) ?? ScanResult(files: [], refused: [])
        let ownIDs = Set(own.files.map(\.id))
        let publications = SpotsModel.publications(of: own, in: folder, store: store)
        let enabled = config.arrangement.enabled.union(folder.enabled)
        let core = folder.keptCoreChoices().filter { !ownIDs.contains(SpotsFolder.coreID(of: $0)) }.map { spot in
            item(spot, id: SpotsFolder.coreID(of: spot), origin: "core", added: enabled.contains(SpotsFolder.coreID(of: spot)))
        }
        let mine = own.files.compactMap { file in file.spots.first.map { (file.id, $0) } }.map { id, spot in
            item(spot, id: id, origin: "mine", added: !folder.disabled.contains(id), published: publications[spot.id].map(Self.word))
        }
        let stored = ((try? SpotsFolder(url: store).scan())?.files ?? []).filter { !ownIDs.contains($0.id) }.compactMap { file in
            file.spots.first.map { item($0, id: file.id, origin: "store", added: false, path: $0.url.deletingLastPathComponent().path) }
        }
        return (core + mine + stored).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func json() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(items), as: UTF8.self) + "\n"
    }

    /// Each spot as a `spot` block (protocol: The openspot command).
    func frame() -> String {
        items.map { item in
            let pairs: [(String, String?)] = [
                ("spot", item.id), ("name", item.name), ("icon", item.icon), ("detail", item.detail), ("size", item.size),
                ("origin", item.origin), ("added", String(item.added)), ("published", item.published), ("path", item.path)
            ]
            return TextBlock(fields: pairs.compactMap { key, value in value.map { TextBlock.Field(key: key, value: $0) } }).text + "\n"
        }.joined()
    }

    private func item(_ spot: Spot, id: String, origin: String, added: Bool, published: String? = nil, path: String? = nil) -> Item {
        let size = config.arrangement.size(of: id) ?? spot.size
        return Item(
            id: id, name: spot.name, icon: spot.image ?? spot.file ?? spot.glyph ?? spot.symbol, detail: spot.subtitle,
            size: size.name, origin: origin, added: added, published: published, path: path
        )
    }

    private static func word(_ publication: SpotPublication) -> String {
        switch publication {
        case .current: "current"
        case .changed: "changed"
        }
    }
}
