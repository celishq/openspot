import Foundation

extension SpotsModel {
    public func arranges(_ entry: Entry) -> Bool {
        takesOffGrid(entry) && !entry.spot.isSource
    }

    public func searchShelf(_ text: String) {
        asOnePress {
            guard text != shelfQuery else { return }
            shelfQuery = text
            takeShelf()
        }
    }

    public func shelfScrolled(to offset: CGFloat) {
        guard shelfScroll != offset else { return }
        shelfScroll = offset
    }

    func takeOffGridSpots(placed: Set<String>) {
        let next = cards
            .filter { !placed.contains($0.id) && arranges($0) }
            .sorted { $0.spot.comesBefore($1.spot) }
        guard next != offGrid else { return }
        offGrid = next
        offGridWords = next.map { ([$0.spot.name] + $0.spot.keywords).joined(separator: " ").folded }
        takeShelf()
    }

    func takeShelf() {
        let next = shelfMatches(of: shelfQuery)
        if next != shelf { shelf = next }
        layShelf()
    }

    public func placeShelf(screen: CGSize, panelOrigin: CGPoint) {
        if shelfRoom?.screen != screen || shelfRoom?.panelOrigin != panelOrigin { shelfSlots = [:] }
        shelfRoom = (screen, panelOrigin)
        layShelf()
    }

    func layShelf() {
        guard let room = shelfRoom else { return }
        let panel = CGRect(x: room.panelOrigin.x + SpotTokens.halo, y: room.panelOrigin.y + SpotTokens.halo, width: SpotTokens.gridWidth, height: SpotTokens.panelHeight)
        let isFull = shelfQuery.trimmingCharacters(in: .whitespaces).isEmpty
        let drop = shelfDrop
        shelfDrop = nil
        let ids = shelf.map(\.id)
        let next = ShelfLayout(
            screen: room.screen,
            panel: panel,
            sizes: shelf.map(\.size),
            slots: isFull ? ids.map { $0 == drop?.id ? drop?.slot : shelfSlots[$0] } : [],
            first: isFull ? ids.firstIndex { $0 == drop?.id } : nil
        )
        if isFull { shelfSlots = Dictionary(uniqueKeysWithValues: zip(ids, next.slots)) }
        if next != shelfLayout { shelfLayout = next }
    }

    func shelfSlot(at corner: CGPoint, size: SpotSize) -> ShelfSlot? {
        guard let layout = shelfLayout, let room = shelfRoom else { return nil }
        let point = CGPoint(x: room.panelOrigin.x + corner.x, y: corner.y + room.panelOrigin.y - layout.band.lowerBound - SpotTokens.scrollFadeLength + shelfScroll)
        return layout.slot(near: point, size: size)
    }

    public func shelfOrigin(of id: String) -> CGPoint? {
        guard let layout = shelfLayout, let room = shelfRoom, let index = shelf.firstIndex(where: { $0.id == id }), layout.rects.indices.contains(index) else { return nil }
        let rect = layout.rects[index]
        return CGPoint(x: rect.minX - room.panelOrigin.x, y: layout.band.lowerBound + SpotTokens.scrollFadeLength + rect.minY - shelfScroll - room.panelOrigin.y)
    }

    func shelfMatches(of text: String) -> [Entry] {
        let words = text.trimmingCharacters(in: .whitespaces).folded
        return words.isEmpty ? offGrid : zip(offGrid, offGridWords).filter { $0.1.contains(words) }.map(\.0)
    }

    public func gridSpots() -> [ArrangedSpot] {
        let placed = Set(laidGrid().spots.map(\.id))
        let spots = cards.filter(arranges).sorted { $0.spot.comesBefore($1.spot) }
        let listed = { (entry: Entry) in
            ArrangedSpot(id: entry.id, name: entry.spot.name, icon: entry.spot.picture, isOnGrid: placed.contains(entry.id))
        }
        return spots.filter { !placed.contains($0.id) }.map(listed) + spots.filter { placed.contains($0.id) }.map(listed)
    }

    private func laidGrid() -> (spots: [Entry], placements: [SpotPlacement]) {
        let shown = cards.filter(\.isOnGrid)
        let laid = grid.place(shown.map { GridSpot(size: $0.size, cell: $0.cell(in: grid)) })
        return (laid.map { shown[$0.index] }, laid.enumerated().map { $0.element.reindexed($0.offset) })
    }

    func clearArrange() {
        if !shelfQuery.isEmpty { shelfQuery = "" }
        shelfScroll = 0
        shelfSlots = [:]
        shelfDrop = nil
        takeShelf()
    }

    public func dragShelfSpot(_ id: String, by translation: CGSize) {
        guard isArranging, gesture?.drag == nil, resize == nil, let origin = shelfOrigin(of: id) else { return }
        let corner = CGPoint(x: origin.x + translation.width, y: origin.y + translation.height)
        if lift.origin != corner { lift.origin = corner }
        if pin?.id != id {
            guard let entry = offGrid.first(where: { $0.id == id }) else { return }
            let grid = SpotTokens.gridOrigin()
            let lifted = SpotPin(
                id: id,
                start: CGPoint(x: origin.x - grid.x, y: origin.y - grid.y),
                size: entry.size,
                choices: sizes(of: entry),
                grid: self.grid,
                placements: placements,
                ids: visible.map { self.takesOffGrid($0) ? $0.id : nil }
            )
            tip = nil
            change(.edit) {
                gesture = .pin(lifted)
                carry = SpotCarry(entry: entry, size: lifted.size)
            }
        }
        guard let pin else { return }
        pointerMove = translation
        let next = pin.moved(by: translation)
        guard next != pin else { return stopDragWait() }
        guard let cell = next.target?.cell else {
            stopDragWait()
            return show(next)
        }
        afterRest(at: cell) {
            guard let pin = self.pin, let move = self.pointerMove else { return }
            self.show(pin.moved(by: move))
        }
    }

    private func show(_ next: SpotPin) {
        guard let pin, next != pin else { return }
        change(.edit) {
            gesture = .pin(next)
            if carry?.size != next.carriedSize { carry?.size = next.carriedSize }
            if next.layout != pin.layout { updateVisible() }
        }
    }

    public func dropShelfSpot(by translation: CGSize) {
        asOnePress {
            guard let pin = pin?.moved(by: translation) else { return }
            stopDragWait()
            pointerMove = nil
            guard let target = pin.target, let entry = offGrid.first(where: { $0.id == pin.id }) else { return moveOnShelf(pin.id, by: translation) }
            var spots = visible
            var layout = pin.layout
            let placement = { (index: Int) in SpotPlacement(index: index, row: target.cell.row, column: target.cell.column, size: target.size) }
            var leaving: String?
            switch target {
            case .slot:
                layout.append(placement(spots.count))
                spots.append(entry)
            case .swap(let id, _, _):
                guard let index = spots.firstIndex(where: { $0.id == id }) else { return cancelPin() }
                spots[index] = entry
                layout[index] = placement(index)
                leaving = id
            }
            saveLayout(layout, of: spots, selecting: pin.id, ending: {
                gesture = nil
                landing = pin.id
            }, landed: { self.endLanding(of: pin.id) }, also: { choices in
                choices.set(isOnGrid: true, of: pin.id)
                if let leaving { choices.set(isOnGrid: false, of: leaving) }
            })
        }
    }

    private func moveOnShelf(_ id: String, by translation: CGSize) {
        guard let origin = shelfOrigin(of: id), let entry = shelf.first(where: { $0.id == id }),
              let slot = shelfSlot(at: CGPoint(x: origin.x + translation.width, y: origin.y + translation.height), size: entry.size) else { return cancelPin() }
        stopDragWait()
        pointerMove = nil
        shelfDrop = (id, slot)
        change(.edit, {
            gesture = nil
            layShelf()
            carryToShelf()
            updateVisible()
        }, completion: { self.endLanding(of: id) })
    }

    func cancelPin() {
        guard pin != nil else { return }
        stopDragWait()
        pointerMove = nil
        change(.edit) {
            gesture = nil
            carry = nil
            updateVisible()
        }
    }

    @discardableResult
    public func pin(_ id: String) -> GridPin {
        asOnePress {
            guard let entry = card(id: id), arranges(entry) else { return .unknown }
            let (spots, layout) = laidGrid()
            guard !spots.contains(where: { $0.id == id }) else { return .onGrid }
            let choices = sizes(of: entry)
            let slots = grid.freeCells(around: layout)
            guard let slot = slots.lazy.compactMap({ slot in self.grid.fit(entry.size, at: slot, among: layout, choices: choices).map { (slot, $0) } }).first else { return .full }
            let placement = SpotPlacement(index: spots.count, row: slot.0.row, column: slot.0.column, size: slot.1)
            saveLayout(layout + [placement], of: spots + [entry], selecting: id, also: { $0.set(isOnGrid: true, of: id) })
            return .pinned(slot.0)
        }
    }
}
