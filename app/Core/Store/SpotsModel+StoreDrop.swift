import Foundation

extension SpotsModel {
    public func beginStoreDrag() {
        if !isShown || isWarming { host.showForDrag() }
        isOpenForDrag = false
        if !isEditing { beginEditing() }
    }

    public func dragStoreSpot(_ id: String, at point: CGPoint) {
        guard isEditing, query.isEmpty, resize == nil, let entry = storeEntry(id) else { return }
        if drag?.id != entry.id {
            incoming = entry
            updateVisible()
            guard let start = visible.firstIndex(where: { $0.id == entry.id }) else { return cancelStoreDrag() }
            let split = shelfStart ?? visible.count
            let isOnGrid = start < split
            let others = split - (isOnGrid ? 1 : 0)
            let shelf = entry.item == nil && entry.spot.offersCard ? (others...(visible.count - 1)).map(SpotDrag.Target.shelf) : []
            let home = SpotDrag.Target(place: start, isOnGrid: isOnGrid, panel: isOnGrid ? panel(of: entry) : .center)
            stopDragWait()
            tip = nil
            change(.edit) {
                drag = SpotDrag(id: entry.id, home: home, sizes: visible.map(\.size), targets: gridTargets(0...others) + shelf, grid: grid)
            }
        }
        guard let drag else { return }
        follow(drag.holds(point) ? drag.nearest(to: point) : drag.home, of: drag)
    }

    public func cancelStoreDrag() {
        guard let incoming else { return }
        self.incoming = nil
        stopDragWait()
        change(.edit) {
            if drag?.id == incoming.id { drag = nil }
            updateVisible()
        }
    }

    @discardableResult
    public func dropStoreSpot(_ id: String, at point: CGPoint) -> Bool {
        let store = self.store
        guard let item = storeItem(id), let entry = storeEntry(id) else { return false }
        if drag?.id != entry.id { dragStoreSpot(id, at: point) }
        guard let drag, drag.id == entry.id else { return false }
        let end = SpotDrag.Target.shelf(visible.count - 1)
        let target = drag.holds(point) ? drag.nearest(to: point) : drag.layout(at: end).isEmpty ? drag.home : end
        stopDragWait()
        var order = (cards.filter(\.isOnGrid) + cards.filter { !$0.isOnGrid }).map(\.id).filter { $0 != entry.id }
        order.insert(entry.id, at: min(target.place, order.count))
        var next = arrangement
        next.arrange(order)
        next.set(isOnGrid: target.isOnGrid, of: entry.id)
        next.set(panel: target.panel, of: entry.id)
        store.turnOn(item, in: &next)
        do {
            try files.config.write(next)
            tookOwnWrite()
        } catch {
            cancelStoreDrag()
            host.notify("\(entry.spot.name) was not added. \(Self.reason(error))")
            return false
        }
        change(.edit) {
            self.drag = nil
            incoming = nil
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
}
