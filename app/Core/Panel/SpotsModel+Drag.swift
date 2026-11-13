import Foundation

/// The drags of Edit Spots: a card moved on the grid, a spot of the store dropped on it or a card dropped on the store, and the scrolls under them.
extension SpotsModel {
    /// Moves the card that the person drags, inside the panel's window, and lifts it when the drag starts. The window
    /// carries it over the panel and the dock. The other cards make room where a release would put it once the pointer has
    /// rested there for `dragRest`, and go back to their places while the pointer is off the grid. A card lands in either
    /// group, while both have cards.
    public func dragSpot(_ id: String, by translation: CGSize) {
        guard isEditing, query.isEmpty, resize == nil, carry?.tile == nil else { return }
        if drag?.id != id {
            guard let start = visible.firstIndex(where: { $0.id == id }) else { return }
            let entry = visible[start]
            let others = visible.filter(\.isOnGrid).count - (entry.isOnGrid ? 1 : 0)
            let hasHidden = !entry.isOnGrid || others < visible.count - 1
            let targets = (0...others).map(SpotDrag.Target.onGrid) + (hasHidden ? (others...(visible.count - 1)).map(SpotDrag.Target.hidden) : [])
            let lifted = SpotDrag(id: id, home: SpotDrag.Target(place: start, isOnGrid: entry.isOnGrid), sizes: visible.map(\.size), targets: targets, grid: grid)
            stopDragWait()
            scrollAtPress = gridScroll
            tip = nil
            change(.edit) {
                drag = lifted
                carry = SpotCarry(entry: entry, size: lifted.placement(at: lifted.home)?.size ?? entry.size)
                selected = start
            }
        }
        pointerMove = translation
        guard let drag else { return }
        let move = inGrid(translation)
        let moved = drag.capped(move, within: windowInGrid)
        if lift.offset != moved { lift.offset = moved }
        let corner = inPanel(drag.rect(at: drag.home).offsetBy(dx: moved.width, dy: moved.height).origin)
        if lift.origin != corner { lift.origin = corner }
        let centre = drag.centre(movedBy: move)
        let isOverDock = dockInGrid?.contains(centre) == true
        if carry?.isOverDock != isOverDock { carry?.isOverDock = isOverDock }
        let target = !isOverDock && drag.holds(centre) ? drag.nearest(to: drag.centre(movedBy: moved)) : drag.home
        follow(target, of: drag)
    }

    /// Makes room at this place once the pointer has rested near it for `dragRest`.
    private func follow(_ target: SpotDrag.Target, of drag: SpotDrag) {
        guard target != drag.target else { return stopDragWait() }
        guard target != dragTarget else { return }
        stopDragWait()
        dragTarget = target
        guard dragRest > .zero else { return land(at: target) }
        let rest = dragRest
        dragWait = Task { [weak self] in
            try? await Task.sleep(for: rest)
            guard !Task.isCancelled, let self, self.dragTarget == target else { return }
            self.land(at: target)
        }
    }

    /// Ends the drag: the card lands at the place nearest the lifted card, and the order is saved. A release on the store
    /// puts the card back and publishes a spot of the spots folder. A release with the pointer off the grid, or where the
    /// card started, puts every card back.
    public func dropSpot(by translation: CGSize) {
        guard let drag else { return }
        let move = inGrid(translation)
        let centre = drag.centre(movedBy: move)
        if dockInGrid?.contains(centre) == true {
            if dock.items.first(where: { $0.id == drag.id })?.isOwn == true {
                let id = drag.id
                Task { await publish(id) }
            }
            return cancelDrag()
        }
        let target = drag.nearest(to: drag.centre(movedBy: drag.capped(move, within: windowInGrid)))
        guard drag.holds(centre), target != drag.home else { return cancelDrag() }
        stopDragWait()
        pointerMove = nil
        var order = (cards.filter(\.isOnGrid) + cards.filter { !$0.isOnGrid }).map(\.id)
        order.removeAll { $0 == drag.id }
        order.insert(drag.id, at: target.place)
        arrangement.arrange(order)
        if target.isOnGrid != drag.home.isOnGrid { arrangement.set(isOnGrid: target.isOnGrid, of: drag.id) }
        saveArrangement(selecting: drag.id, ending: {
            self.drag = nil
            landing = drag.id
        }, landed: { self.endLanding(of: drag.id) })
    }

    /// Moves a spot of the store that is not on the grid, which the person drags, and lifts its card out of the store when
    /// the drag starts. While the card lies over the grid, it takes the size it has there, and the other cards make room where a
    /// release would turn it on once the pointer has rested there for `dragRest`. A spot that is on stays, and its card on
    /// the grid is selected.
    public func dragDockSpot(_ id: String, by translation: CGSize) {
        guard isEditing, query.isEmpty, resize == nil else { return }
        if carry?.entry.id != id {
            guard carry == nil, drag == nil, let item = dock.shown.first(where: { $0.id == id }) else { return }
            guard item.state != .onGrid else {
                if let index = visible.firstIndex(where: { $0.id == id }), selected != index { selected = index }
                return
            }
            guard let tile = tileRect(of: id) else { return }
            let entry = Entry(spot: item.spot, run: nil, choice: arrangement, defaults: defaultArrangement)
            let start = visible.filter(\.isOnGrid).count
            var sizes = visible.map(\.size)
            sizes.insert(item.size, at: start)
            let kept = Set(grid.kept.map { $0 >= start ? $0 + 1 : $0 }).union([start])
            arrival = SpotDrag(id: id, start: start, sizes: sizes, places: 0...start, grid: SpotGrid(kept: kept))
            stopDragWait()
            lift.origin = tile.origin
            change(.edit) { carry = SpotCarry(entry: entry, size: item.size, tile: tile) }
        }
        pointerMove = translation
        guard let carry, let tile = carry.tile, var arrival else { return }
        let centre = CGPoint(x: tile.midX + translation.width, y: tile.midY + translation.height)
        let grid = SpotTokens.gridOrigin(scrollOffset: gridScroll)
        let point = CGPoint(x: centre.x - grid.x, y: centre.y - grid.y)
        let panel = CGRect(x: 0, y: 0, width: SpotTokens.panelWidth, height: SpotTokens.panelHeight)
        let isOverGrid = panel.contains(centre) && dockFrame?.contains(centre) != true && arrival.holds(point)
        let size = isOverGrid ? arrival.placement(at: arrival.home)?.size ?? carry.entry.size : dock.items.first { $0.id == id }?.size ?? carry.size
        if carry.size != size { self.carry?.size = size }
        let card = CGSize(width: SpotTokens.width(columns: size.columns), height: SpotTokens.height(rows: size.rows))
        let origin = held(CGRect(x: centre.x - card.width / 2, y: centre.y - card.height / 2, width: card.width, height: card.height))
        if lift.origin != origin { lift.origin = origin }
        guard isOverGrid else {
            guard drag != nil else { return }
            stopDragWait()
            return change(.edit) {
                drag = nil
                updateVisible()
            }
        }
        let start = arrival.rect(at: arrival.home)
        let offset = CGSize(width: origin.x - grid.x - start.minX, height: origin.y - grid.y - start.minY)
        if lift.offset != offset { lift.offset = offset }
        let target = arrival.nearest(to: arrival.centre(movedBy: offset))
        guard let drag else {
            arrival.target = target
            return change(.edit) {
                drag = arrival
                updateVisible()
            }
        }
        follow(target, of: drag)
    }

    /// Ends the drag of a spot of the dock: over the grid it turns on at the place nearest its card, and anywhere else it
    /// goes back to the dock.
    public func dropDockSpot(by translation: CGSize) {
        guard let carry, carry.tile != nil else { return }
        dragDockSpot(carry.entry.id, by: translation)
        guard let drag, drag.id == carry.entry.id else { return sendBack() }
        turnOnDropped(carry.entry, at: drag.nearest(to: drag.centre(movedBy: lift.offset)).place)
    }

    /// Turns on a spot of the dock that the person dropped on the grid, at this place, and lands its card there, on the grid
    /// at the size that the dock gave it.
    private func turnOnDropped(_ entry: Entry, at place: Int) {
        stopDragWait()
        pointerMove = nil
        arrival = nil
        var order = (cards.filter(\.isOnGrid) + cards.filter { !$0.isOnGrid }).map(\.id)
        order.insert(entry.id, at: min(place, order.count))
        var next = arrangement
        next.arrange(order)
        next.set(isEnabled: true, of: files.folder.fileID(of: entry.spot))
        next.set(isOnGrid: true, of: entry.id)
        if let size = dock.items.first(where: { $0.id == entry.id })?.size { next.set(size: size, of: entry.id) }
        do {
            try files.config.write(next)
        } catch {
            host.notify("\(entry.spot.name) was not turned on. \(Self.reason(error))")
            return sendBack()
        }
        change(.edit, {
            drag = nil
            landing = entry.id
            reload()
            if let index = visible.firstIndex(where: { $0.id == entry.id }) { selected = index }
            carryHome()
        }, completion: { self.endLanding(of: entry.id) })
    }

    /// Puts a carried spot of the dock back: its card leaves the grid, and glides back to its tile.
    private func sendBack() {
        guard let carry, let tile = carry.tile else { return }
        let id = carry.entry.id
        stopDragWait()
        pointerMove = nil
        arrival = nil
        if let size = dock.items.first(where: { $0.id == id })?.size, size != carry.size { self.carry?.size = size }
        let home = tileRect(of: id) ?? tile
        change(.edit, {
            drag = nil
            updateVisible()
            lift.origin = home.origin
            self.carry?.isLanding = true
        }, completion: { self.endLanding(of: id) })
    }

    /// Where the card of a spot of the dock lies in the panel's space, as the dock shows it now.
    private func tileRect(of id: String) -> CGRect? {
        guard let dockFrame, let index = dock.shown.firstIndex(where: { $0.id == id }) else { return nil }
        return dock.rects[index].offsetBy(dx: dockFrame.minX + SpotDock.rowsOrigin.x, dy: dockFrame.minY + SpotDock.rowsOrigin.y - dockScroll)
    }

    /// Takes how far the dock has scrolled. A scroll ends the tip.
    public func dockScrolled(to offset: CGFloat) {
        if dockScroll != offset, tip != nil { tip = nil }
        dockScroll = offset
    }

    /// Puts the dragged card and the cards that made room back where they were. A spot of the dock goes back to the dock.
    public func cancelDrag() {
        if carry?.tile != nil { return sendBack() }
        guard let drag else { return }
        stopDragWait()
        pointerMove = nil
        change(.edit, {
            self.drag = nil
            landing = drag.id
            updateVisible()
            selected = drag.start
            carryHome()
        }, completion: { self.endLanding(of: drag.id) })
    }

    /// Moves the carried card to the place of its card on the grid, where it lands, and off the dock.
    func carryHome() {
        guard let id = carry?.entry.id, let index = visible.firstIndex(where: { $0.id == id }), placements.indices.contains(index) else { return }
        lift.origin = inPanel(placements[index].rect.origin)
        carry?.isOverDock = false
        carry?.isLanding = true
    }

    /// Ends the landing of a card, and clears the pointer's move, which no card reads once the drag ends, and the carried
    /// card. The move stays through the landing, because a change of it there would move the card ahead of the landing's
    /// motion.
    private func endLanding(of id: String) {
        if landing == id { landing = nil }
        if drag == nil, carry?.entry.id == id { carry = nil }
        if drag == nil, lift.offset != .zero { lift.offset = .zero }
    }

    /// Takes how far the grid has scrolled, and ends the tip. A card that the person drags or resizes moves with the grid, as
    /// if the pointer moved as far.
    public func gridScrolled(to offset: CGFloat) {
        guard gridScroll != offset else { return }
        gridScroll = offset
        if tip != nil { tip = nil }
        guard let move = pointerMove else { return }
        if let carry, carry.tile != nil {
            dragDockSpot(carry.entry.id, by: move)
        } else if let drag {
            dragSpot(drag.id, by: move)
        } else if let resize {
            resizeSpot(resize.id, by: move)
        }
    }

    /// The pointer's move as a move over the grid, with the scroll since the press added.
    func inGrid(_ translation: CGSize) -> CGSize {
        CGSize(width: translation.width, height: translation.height + gridScroll - scrollAtPress)
    }

    /// The panel's window in the grid's places, a padding inside its edges, where a lifted card stays. In Edit Spots it
    /// holds the dock too.
    private var windowInGrid: CGRect {
        let origin = SpotTokens.gridOrigin(scrollOffset: gridScroll)
        return windowInPanel.offsetBy(dx: -origin.x, dy: -origin.y)
    }

    /// The panel's window in the panel's space, a padding inside its edges. In Edit Spots it holds the dock too.
    private var windowInPanel: CGRect {
        let panel = CGRect(x: 0, y: 0, width: SpotTokens.panelWidth, height: SpotTokens.panelHeight)
        return panel.union(dockFrame ?? panel).insetBy(dx: SpotTokens.padding, dy: SpotTokens.padding)
    }

    /// The top left corner that keeps this card inside the window, nearest to its own.
    private func held(_ card: CGRect) -> CGPoint {
        let window = windowInPanel
        return CGPoint(x: min(max(card.minX, window.minX), window.maxX - card.width), y: min(max(card.minY, window.minY), window.maxY - card.height))
    }

    /// The dock in the grid's places.
    private var dockInGrid: CGRect? {
        let origin = SpotTokens.gridOrigin(scrollOffset: gridScroll)
        return dockFrame?.offsetBy(dx: -origin.x, dy: -origin.y)
    }

    /// A point of the grid in the panel's space.
    private func inPanel(_ point: CGPoint) -> CGPoint {
        let origin = SpotTokens.gridOrigin(scrollOffset: gridScroll)
        return CGPoint(x: point.x + origin.x, y: point.y + origin.y)
    }

    /// These cards with the dragged card moved to its place.
    func dragged(_ list: [Entry]) -> [Entry] {
        guard let drag, let from = list.firstIndex(where: { $0.id == drag.id }) else { return list }
        var list = list
        let entry = list.remove(at: from)
        list.insert(entry, at: min(drag.place, list.count))
        return list
    }

    private func land(at target: SpotDrag.Target) {
        dragTarget = nil
        change(.edit) {
            drag?.target = target
            updateVisible()
            selected = target.place
        }
    }

    func stopDragWait() {
        dragWait?.cancel()
        dragWait = nil
        dragTarget = nil
    }
}
