import Foundation
import Observation

/// Edit Spots: the order, the size and the place on the grid of each spot.
extension SpotsModel {
    /// The packing rule at the panel's columns.
    public var grid: SpotGrid {
        SpotGrid(columns: panelSize.columns)
    }

    /// Sets the size of the panel's grid, saves it, and lays out the cards at its columns.
    public func setPanelSize(_ size: PanelSize) {
        guard size != panelSize else { return }
        save(size)
        change(.edit) {
            panelSize = size
            updateVisible()
        }
    }

    /// Resizes the panel by its corner: it takes the size whose corner lies nearest the pointer, with no fewer rows than its
    /// cards need and no larger than `panelLimit`, and the cards make room.
    public func resizePanel(by translation: CGSize) {
        guard isEditing, drag == nil, resize == nil else { return }
        let resize = panelResize ?? PanelResize(start: panelSize, sizes: visible.filter(\.isOnGrid).map(\.size), limit: panelLimit)
        panelResize = resize
        let target = resize.nearest(to: resize.corner(movedBy: translation))
        guard target != panelSize else { return }
        change(.edit) {
            panelSize = target
            updateVisible()
        }
    }

    /// Ends the resize of the panel, and saves its size when it changed.
    public func dropPanelResize() {
        guard let resize = panelResize else { return }
        panelResize = nil
        if panelSize != resize.start { save(panelSize) }
    }

    /// Puts the panel back at the size it had when the resize started.
    public func cancelPanelResize() {
        guard let resize = panelResize else { return }
        panelResize = nil
        change(.edit) {
            panelSize = resize.start
            updateVisible()
        }
    }

    private func save(_ size: PanelSize) {
        do {
            try files.config.set("panel_size", to: size.text)
        } catch {
            host.notify("Openspot could not save the size of the panel. \(Self.reason(error))")
        }
    }

    /// The sizes that a person can prefer for a spot, in words for its menu.
    public func sizes(of entry: Entry) -> [SpotSize] {
        entry.item == nil ? entry.command.sizes : []
    }

    /// Starts Edit Spots on the grid, with the search cleared.
    public func beginEditing() {
        guard openList == nil else { return }
        closeMenu()
        change(.edit) {
            query = ""
            isEditing = true
            updateVisible()
        }
    }

    /// Ends Edit Spots. A panel that closes passes no motion, so that nothing moves during its fade.
    public func endEditing(moving: Bool = true) {
        guard isEditing else { return }
        stopDragWait()
        change(moving ? .edit : nil) {
            if let resize = panelResize { panelSize = resize.start }
            panelResize = nil
            isEditing = false
            drag = nil
            landing = nil
            resize = nil
            pointerMove = nil
            if lift.offset != .zero { lift.offset = .zero }
            selected = 0
            updateVisible()
        }
    }

    public func handleEditKey(_ key: ActionKey) {
        if drag != nil || resize != nil || panelResize != nil {
            if key.name == "escape" {
                cancelDrag()
                cancelResize()
                cancelPanelResize()
            }
            return
        }
        if openNewSpot(on: key) { return }
        let order = visible.map(\.id)
        switch (key.name, key.isShift) {
        case ("escape", _): endEditing()
        case ("left", false): moveSelection(dx: -1, dy: 0)
        case ("right", false): moveSelection(dx: 1, dy: 0)
        case ("up", false): moveSelection(dx: 0, dy: -1)
        case ("down", false): moveSelection(dx: 0, dy: 1)
        case ("left", true), ("up", true): moveSelectedSpot(by: -1, in: order)
        case ("right", true), ("down", true): moveSelectedSpot(by: 1, in: order)
        case ("s", _): stepSelectedSize()
        case ("h", _): toggleSelectedOnGrid()
        default: break
        }
    }

    /// Moves the card that the person drags, and lifts it when the drag starts. The other cards make room where a release
    /// would put it once the pointer has rested there for `dragRest`. A card on the grid lands among the cards on the grid,
    /// and a hidden card among the hidden cards.
    public func dragSpot(_ id: String, by translation: CGSize) {
        guard isEditing, query.isEmpty, resize == nil else { return }
        if drag?.id != id {
            guard let start = visible.firstIndex(where: { $0.id == id }) else { return }
            let onGrid = visible.filter(\.isOnGrid).count
            let places = visible[start].isOnGrid ? 0...(onGrid - 1) : onGrid...(visible.count - 1)
            stopDragWait()
            scrollAtPress = gridScroll
            change(.edit) {
                drag = SpotDrag(id: id, start: start, sizes: visible.map(\.size), places: places, grid: grid)
                selected = start
            }
        }
        pointerMove = translation
        let moved = inGrid(translation)
        if lift.offset != moved { lift.offset = moved }
        guard let drag else { return }
        let target = drag.nearest(to: drag.centre(movedBy: moved))
        guard target != drag.place else { return stopDragWait() }
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

    /// Ends the drag: the card lands at the place nearest the pointer, and the order is saved. A release off the grid, or
    /// where the card started, puts every card back.
    public func dropSpot(by translation: CGSize) {
        guard let drag else { return }
        let centre = drag.centre(movedBy: inGrid(translation))
        let place = drag.nearest(to: centre)
        guard drag.holds(centre), place != drag.start else { return cancelDrag() }
        stopDragWait()
        pointerMove = nil
        var order = dragged(cards.filter(\.isOnGrid) + cards.filter { !$0.isOnGrid }).map(\.id)
        order.removeAll { $0 == drag.id }
        order.insert(drag.id, at: place)
        arrangement.arrange(order)
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
        }, completion: { self.endLanding(of: drag.id) })
    }

    /// Ends the landing of a card, and clears the pointer's move, which no card reads once the drag ends. The move stays
    /// through the landing, because a change of it there would move the card ahead of the landing's motion.
    private func endLanding(of id: String) {
        if landing == id { landing = nil }
        if drag == nil, lift.offset != .zero { lift.offset = .zero }
    }

    /// Resizes a card by its corner: it takes the size whose corner lies nearest the pointer, and the other cards make room.
    public func resizeSpot(_ id: String, by translation: CGSize) {
        guard isEditing, query.isEmpty, drag == nil else { return }
        if resize?.id != id {
            guard let index = visible.firstIndex(where: { $0.id == id }) else { return }
            resize = SpotResize(id: id, index: index, sizes: visible.map(\.size), choices: sizes(of: visible[index]), grid: grid)
            scrollAtPress = gridScroll
            selected = index
        }
        pointerMove = translation
        guard let resize else { return }
        let target = resize.nearest(to: resize.corner(movedBy: inGrid(translation)))
        guard target != resize.size else { return }
        change(.edit) {
            self.resize?.size = target
            updateVisible()
        }
    }

    /// Ends the resize, and saves the size as the card's preferred size when it changed.
    public func dropResize() {
        guard let resize else { return }
        pointerMove = nil
        guard resize.size != resize.start else { return cancelResize() }
        arrangement.arrange(visible.map(\.id))
        arrangement.set(size: resize.size, of: resize.id)
        saveArrangement(selecting: resize.id) { self.resize = nil }
    }

    /// Puts the resized card and the cards that made room back as they were.
    public func cancelResize() {
        guard resize != nil else { return }
        pointerMove = nil
        change(.edit) {
            resize = nil
            updateVisible()
        }
    }

    /// Takes how far the grid has scrolled. A card that the person drags or resizes moves with the grid, as if the pointer
    /// moved as far.
    public func gridScrolled(to offset: CGFloat) {
        guard gridScroll != offset else { return }
        gridScroll = offset
        guard let move = pointerMove else { return }
        if let drag {
            dragSpot(drag.id, by: move)
        } else if let resize {
            resizeSpot(resize.id, by: move)
        }
    }

    /// The pointer's move as a move over the grid, with the scroll since the press added.
    private func inGrid(_ translation: CGSize) -> CGSize {
        CGSize(width: translation.width, height: translation.height + gridScroll - scrollAtPress)
    }

    /// These cards with the dragged card moved to its place.
    func dragged(_ list: [Entry]) -> [Entry] {
        guard let drag, let from = list.firstIndex(where: { $0.id == drag.id }) else { return list }
        var list = list
        let entry = list.remove(at: from)
        list.insert(entry, at: min(drag.place, list.count))
        return list
    }

    private func land(at place: Int) {
        dragTarget = nil
        change(.edit) {
            drag?.place = place
            updateVisible()
            selected = place
        }
    }

    private func stopDragWait() {
        dragWait?.cancel()
        dragWait = nil
        dragTarget = nil
    }

    private func moveSelectedSpot(by step: Int, in order: [String]) {
        guard order.indices.contains(selected),
              let place = grid.nextPlace(of: selected, in: visible.map(\.size), step: step) else { return }
        moveSpot(order[selected], to: place)
    }

    /// Puts a spot at this place in the grid, and keeps it selected.
    public func moveSpot(_ id: String, to place: Int) {
        var order = visible.map(\.id)
        guard let from = order.firstIndex(of: id), order.indices.contains(place), place != from else { return }
        order.remove(at: from)
        order.insert(id, at: place)
        arrangement.arrange(order)
        saveArrangement(selecting: id)
    }

    private func stepSelectedSize() {
        guard let entry = selectedEntry else { return }
        let sizes = visible.map(\.size)
        if let next = grid.nextSize(of: selected, in: sizes, among: self.sizes(of: entry)) { prefer(next, for: entry.id) }
    }

    private func toggleSelectedOnGrid() {
        guard let entry = selectedEntry else { return }
        setOnGrid(!entry.isOnGrid, for: entry.id)
    }

    /// Takes a preferred size for a spot. The grid can still change it to fill a row.
    public func prefer(_ size: SpotSize, for id: String) {
        arrangement.arrange(visible.map(\.id))
        arrangement.set(size: size, of: id)
        saveArrangement(selecting: id)
    }

    public func setOnGrid(_ isOn: Bool, for id: String) {
        arrangement.arrange((cards.filter(\.isOnGrid) + cards.filter { !$0.isOnGrid }).map(\.id))
        arrangement.set(isOnGrid: isOn, of: id)
        saveArrangement(selecting: id)
    }

    /// Writes the arrangement, and lays out the cards from it on the edit motion, after `ending` runs in that motion.
    /// `landed` runs when the motion ends.
    private func saveArrangement(selecting id: String, ending: () -> Void = {}, landed: @escaping @MainActor () -> Void = {}) {
        do {
            try files.config.write(arrangement)
        } catch {
            host.notify("Openspot could not save the spots. \(Self.reason(error))")
        }
        change(.edit, {
            ending()
            rebuildEntries()
            if let place = visible.firstIndex(where: { $0.id == id }) { selected = place }
        }, completion: landed)
    }
}
