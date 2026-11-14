import Foundation

extension SpotsModel {
    public func storeEntry(_ id: String) -> Entry? {
        keptStoreCards()[id]?.entry
    }

    public func sample(_ id: String) async -> SpotOutput? {
        guard let item = storeItem(id), let text = await SpotListing.sample(of: item.spot, runsScript: item.origin != .store, runs: runs) else { return nil }
        return SpotOutput(text: text)
    }

    func storeItem(_ id: String) -> SpotStore.Item? {
        keptStoreCards()[id]?.item
    }

    private func keptStoreCards() -> [String: (entry: Entry, item: SpotStore.Item)] {
        if let storeCards { return storeCards }
        let folder = self.folder
        let shown = Dictionary(cards.filter { $0.item == nil }.map { (SpotStore.id(of: $0.spot, in: folder), $0) }, uniquingKeysWith: { first, _ in first })
        let read = Dictionary(store.items(publications: false).map { item in
            (item.id, (entry: shown[item.id] ?? Entry(spot: item.spot, run: nil, choice: arrangement, defaults: defaultArrangement), item: item))
        }, uniquingKeysWith: { first, _ in first })
        storeCards = read
        return read
    }
}
