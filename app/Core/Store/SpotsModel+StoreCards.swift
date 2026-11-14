import Foundation

/// The cards that the store draws: the card of a spot that the panel has, or else a card from the header of a spot that
/// comes with the app, that the person turned off, or that the store holds, with no run behind it.
extension SpotsModel {
    /// The entry of a spot of the store by its store ID, or nil when no spot has it. It reads the store once after each
    /// load of the spots, and a view that draws the cards only looks it up.
    public func storeEntry(_ id: String) -> Entry? {
        if storeCards == nil { storeCards = readStoreCards() }
        return storeCards?[id]
    }

    private func readStoreCards() -> [String: Entry] {
        let folder = self.folder
        let shown = Dictionary(cards.filter { $0.item == nil }.map { (SpotStore.id(of: $0.spot, in: folder), $0) }, uniquingKeysWith: { first, _ in first })
        return Dictionary(store.items.map { item in
            (item.id, shown[item.id] ?? Entry(spot: item.spot, run: nil, choice: arrangement, defaults: defaultArrangement))
        }, uniquingKeysWith: { first, _ in first })
    }
}
