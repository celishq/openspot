import Foundation

/// The drags of Edit Spots: a card moved on the grid, and the scrolls under it.
extension SpotsModel {
    /// Moves the card that the person drags, inside the panel's window, and lifts it when the drag starts. The window
    /// carries it over the panel. The other cards make room where a release would put it once the pointer has
    /// rested there for `dragRest`, and go back to their places while the pointer is off the grid. A card lands in either
    /// group, while both have cards.
    public func dragSpot(_ id: String, by translation: CGSize) {
        guard isEditing, query.isEmpty, resize == nil else { return }
        if drag?.id != id {
            guard let start = visible.firstIndex(where: { $0.id == id }) else { return }
            let entry = visible[start]
            let others = visible.filter(\.isOnGrid).count - (entry.isOnGrid ? 1 : 0)
            let targets = gridTargets(0...others) + (entry.item == nil && entry.spot.offersCard ? (others...(visible.count - 1)).map(SpotDrag.Target.hidden) : [])
            let home = SpotDrag.Target(place: start, isOnGrid: entry.isOnGrid, panel: entry.isOnGrid ? panel(of: entry) : .center)
            let lifted = SpotDrag(id: id, home: home, sizes: visible.map(\.size), targets: targets, grid: grid)
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
        let target = drag.holds(centre) ? drag.nearest(to: drag.centre(movedBy: moved)) : drag.home
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

    /// Ends the drag: the card lands at the place nearest the lifted card, and the order is saved. A release with the
    /// pointer off the grid, or where the card started, puts every card back.
    public func dropSpot(by translation: CGSize) {
        guard let drag else { return }
        let move = inGrid(translation)
        let centre = drag.centre(movedBy: move)
        let target = drag.nearest(to: drag.centre(movedBy: drag.capped(move, within: windowInGrid)))
        guard drag.holds(centre), target != drag.home else { return cancelDrag() }
        stopDragWait()
        pointerMove = nil
        var order = (cards.filter(\.isOnGrid) + cards.filter { !$0.isOnGrid }).map(\.id)
        order.removeAll { $0 == drag.id }
        order.insert(drag.id, at: target.place)
        arrangement.arrange(order)
        if target.isOnGrid != drag.home.isOnGrid { arrangement.set(isOnGrid: target.isOnGrid, of: drag.id) }
        arrangement.set(panel: target.panel, of: drag.id)
        saveArrangement(selecting: drag.id, ending: {
            self.drag = nil
            landing = drag.id
        }, landed: { self.endLanding(of: drag.id) })
    }

    /// Puts the dragged card and the cards that made room back where they were.
    public func cancelDrag() {
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

    /// Moves the carried card to the place of its card on the grid, where it lands.
    func carryHome() {
        guard let id = carry?.entry.id, let index = visible.firstIndex(where: { $0.id == id }), placements.indices.contains(index) else { return }
        lift.origin = inPanel(placements[index].rect.origin)
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
        if let drag {
            dragSpot(drag.id, by: move)
        } else if let resize {
            resizeSpot(resize.id, by: move)
        }
    }

    /// The pointer's move as a move over the grid, with the scroll since the press added.
    func inGrid(_ translation: CGSize) -> CGSize {
        CGSize(width: translation.width, height: translation.height + gridScroll - scrollAtPress)
    }

    /// The panel's window in the grid's places, a padding inside its edges, where a lifted card stays.
    private var windowInGrid: CGRect {
        let origin = gridOrigin
        return windowInPanel.offsetBy(dx: -origin.x, dy: -origin.y)
    }

    /// The panel's window in the panel's space, a padding inside its edges.
    private var windowInPanel: CGRect {
        panels.frame.insetBy(dx: SpotTokens.padding, dy: SpotTokens.padding)
    }

    /// A point of the grid in the panel's space.
    private func inPanel(_ point: CGPoint) -> CGPoint {
        let origin = gridOrigin
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

    /// The panel that a card lies in: its side, while the grid has that side, and else the center.
    func panel(of entry: Entry) -> GridPanel {
        panels.holding(entry.panel)
    }

    /// The places on the grid that a dragged card may take, in each panel that the grid has.
    private func gridTargets(_ places: ClosedRange<Int>) -> [SpotDrag.Target] {
        GridPanel.allCases.filter { panels[$0] }.flatMap { panel in places.map { SpotDrag.Target.onGrid($0, panel: panel) } }
    }

    /// Where the grid's top left corner lies in the panel, as the grid has scrolled.
    public var gridOrigin: CGPoint {
        SpotTokens.gridOrigin(scrollOffset: gridScroll, left: panels.leftExtent)
    }
}
