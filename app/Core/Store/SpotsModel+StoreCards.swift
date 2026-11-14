import Foundation

/// The cards that the store draws: the card of a spot that the panel has, or else a card from the header of a spot that
/// comes with the app, that the person turned off, or that the store holds, with no run behind it.
extension SpotsModel {
    /// The entry of a spot of the store by the ID that `openspot store list` prints, or nil when no spot has it. It reads
    /// the folders once after each load of the spots, and a view that draws the cards only looks it up.
    public func storeEntry(_ id: String) -> Entry? {
        if storeCards == nil { storeCards = readStoreCards() }
        return storeCards?[id]
    }

    /// Each entry of the store by its store ID: the cards of the panel first, then the core spots, the person's own files
    /// and the packages of the store that the panel lacks.
    private func readStoreCards() -> [String: Entry] {
        let folder = self.folder
        var found: [String: Entry] = [:]
        for card in cards where card.item == nil {
            found[folder.fileID(of: card.spot)] = card
            found[card.id] = card
        }
        let headers = folder.keptCoreChoices().map { (SpotsFolder.coreID(of: $0), $0) }
            + ((try? SpotsFolder(url: folder.url).keptScan())?.files ?? []).compactMap { file in file.spots.first.map { (file.id, $0) } }
            + ((try? SpotsFolder(url: files.store).keptScan())?.files ?? []).compactMap { file in file.spots.first.map { (file.id, $0) } }
        for (id, spot) in headers where found[id] == nil {
            found[id] = Entry(spot: spot, run: nil, choice: arrangement, defaults: defaultArrangement)
        }
        return found
    }
}
