import Foundation

/// The cards that the store draws: the card of a spot that the panel has, or else a card from the header of a spot that
/// comes with the app or that the store holds, with no run behind it.
extension SpotsModel {
    /// The entry of a spot of the store by the ID that `openspot store list` prints, or nil when no spot has it.
    public func storeEntry(_ id: String) -> Entry? {
        let folder = self.folder
        if let card = cards.first(where: { $0.item == nil && ($0.id == id || folder.fileID(of: $0.spot) == id) }) { return card }
        let core = folder.keptCoreChoices().first { SpotsFolder.coreID(of: $0) == id }
        let stored = core == nil ? ((try? SpotsFolder(url: files.store).keptScan())?.files.first { $0.id == id }?.spots.first) : nil
        return (core ?? stored).map { Entry(spot: $0, run: nil, choice: arrangement, defaults: defaultArrangement) }
    }
}
