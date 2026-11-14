import Foundation

/// The cards that the store draws: the card of a spot that the panel has, or else a card from the header of a spot that
/// comes with the app, that the person turned off, or that the store holds, with no run behind it.
extension SpotsModel {
    /// The entry of a spot of the store by its store ID, or nil when no spot has it. It reads the store's headers once after
    /// each load of the spots, and a view that draws the cards only looks it up.
    public func storeEntry(_ id: String) -> Entry? {
        keptStoreCards()[id]?.entry
    }

    /// The spot of the store by its store ID, from the same read as its card.
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
