import Foundation

extension SpotsModel {
    public func beginStoreDrag() {
        if !isShown || isWarming { host.showForDrag() }
        isOpenForDrag = false
        if !isEditing { beginEditing() }
    }

    @discardableResult
    public func dropStoreSpot(_ id: String, at point: CGPoint) -> Bool {
        let store = self.store
        guard let item = storeItem(id), let entry = storeEntry(id) else { return false }
        let isUnderCards = point.y > SpotGrid.height(of: placements) + SpotTokens.rowGap
        let target = isUnderCards ? nil : placements.min { distance($0.rect, point) < distance($1.rect, point) }
        let place = target?.index ?? visible.count
        let isOnGrid = target.map { visible[$0.index].isOnGrid } ?? !isUnderCards
        var order = visible.map(\.id).filter { $0 != entry.id }
        order.insert(entry.id, at: min(place, order.count))
        var next = arrangement
        next.arrange(order + cards.map(\.id).filter { !order.contains($0) })
        next.set(isOnGrid: isOnGrid, of: entry.id)
        store.turnOn(item, in: &next)
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
        if item.package != nil {
            let environment = files.environment
            Task {
                do {
                    try await store.add(item, environment: environment)
                } catch {
                    host.notify("\(entry.spot.name) was not added. \(Self.reason(error))")
                }
            }
        }
        return true
    }

    private func distance(_ rect: CGRect, _ point: CGPoint) -> CGFloat {
        hypot(rect.midX - point.x, rect.midY - point.y)
    }
}
