import Foundation

/// The drag of a card out of the store: it opens Edit Spots for the drag, and a drop on the grid or the shelf adds the spot
/// at that place.
extension SpotsModel {
    /// Opens the panel in Edit Spots for a drag of a store card. The panel stays in Edit Spots after the drag, also when the
    /// card lands elsewhere.
    public func beginStoreDrag() {
        if !isShown || isWarming { host.showForDrag() }
        isOpenForDrag = false
        if !isEditing { beginEditing() }
    }

    /// Adds the spot of a store card at the place of the grid nearest this point of the grid, on the grid or the shelf as
    /// that place is: it turns on a core spot or the person's own, or adds a package of the store first. A spot that the
    /// panel has moves there. Returns false when no spot has the ID.
    @discardableResult
    public func dropStoreSpot(_ id: String, at point: CGPoint) -> Bool {
        guard let entry = storeEntry(id) else { return false }
        let target = placements.min { distance($0.rect, point) < distance($1.rect, point) }
        let place = target?.index ?? visible.filter(\.isOnGrid).count
        let isOnGrid = target.map { visible[$0.index].isOnGrid } ?? true
        var order = visible.map(\.id).filter { $0 != entry.id }
        order.insert(entry.id, at: min(place, order.count))
        var next = arrangement
        next.arrange(order + cards.map(\.id).filter { !order.contains($0) })
        next.set(isOnGrid: isOnGrid, of: entry.id)
        let stored = entry.spot.url.standardizedFileURL.path.hasPrefix(files.store.standardizedFileURL.path + "/")
        if !stored { next.set(isEnabled: true, of: folder.fileID(of: entry.spot)) }
        do {
            try files.config.write(next)
            tookOwnWrite()
        } catch {
            host.notify("\(entry.spot.name) was not added. \(Self.reason(error))")
            return false
        }
        change(.edit) {
            reload()
            if let index = visible.firstIndex(where: { $0.id == entry.id }) { selected = index }
        }
        if stored { addStored(entry.spot) }
        return true
    }

    /// Adds a package of the store to the spots folder, which loads it when the folder changes.
    private func addStored(_ spot: Spot) {
        let source = spot.url.deletingLastPathComponent()
        let folder = self.folder.url
        let environment = files.environment
        Task {
            do {
                _ = try await SpotLock.standard(environment: environment).add(SpotSource(text: source.path, place: source), to: folder, isConfirmed: false)
            } catch {
                host.notify("\(spot.name) was not added. \(Self.reason(error))")
            }
        }
    }

    private func distance(_ rect: CGRect, _ point: CGPoint) -> CGFloat {
        hypot(rect.midX - point.x, rect.midY - point.y)
    }
}
