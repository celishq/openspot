import Foundation

extension SpotsModel {
    public func storeEntry(_ id: String) -> Entry? {
        keptStoreCards()[id]?.entry
    }

    public func sample(_ id: String) async -> SpotOutput? {
        guard let item = storeItem(id) else { return nil }
        return await SpotSample.output(of: item, runs: runs)
    }

    func storeItem(_ id: String) -> SpotCatalog.Item? {
        keptStoreCards()[id]?.item
    }

    private func keptStoreCards() -> [String: (entry: Entry, item: SpotCatalog.Item)] {
        if let storeCards { return storeCards }
        let folder = self.folder
        let shown = Dictionary(cards.filter { $0.item == nil }.map { (SpotCatalog.id(of: $0.spot, in: folder), $0) }, uniquingKeysWith: { first, _ in first })
        let read = Dictionary(catalog.items(publications: false).map { item in
            (item.id, (entry: shown[item.id] ?? Entry(spot: item.spot, run: nil, choice: arrangement, defaults: defaultArrangement), item: item))
        }, uniquingKeysWith: { first, _ in first })
        storeCards = read
        return read
    }
}
