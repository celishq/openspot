import Foundation

extension SpotsModel {
    public func arranges(_ entry: Entry) -> Bool {
        takesOffGrid(entry) && !entry.spot.isAttachmentSource
    }

    public func searchShelf(_ text: String) {
        asOnePress { _ = shelf.search(text) }
    }

    func takeOffGridSpots(placed: Set<String>) {
        shelf.take(offGrid: cards
            .filter { !placed.contains($0.id) && arranges($0) }
            .sorted { $0.spot.comesBefore($1.spot) })
    }

    public func gridSpots() -> [ArrangedSpot] {
        let placed = Set(laidGrid().spots.map(\.id))
        let spots = cards.filter(arranges).sorted { $0.spot.comesBefore($1.spot) }
        let listed = { (entry: Entry) in
            ArrangedSpot(id: entry.id, name: entry.spot.name, icon: entry.spot.picture, isOnGrid: placed.contains(entry.id))
        }
        return spots.filter { !placed.contains($0.id) }.map(listed) + spots.filter { placed.contains($0.id) }.map(listed)
    }

    public func push(_ id: String) -> GridPush {
        asOnePress {
            guard let entry = card(id: id), arranges(entry) else { return .unknown }
            let top = GridCell(row: 0, column: 0)
            let others = laidGrid().spots.filter { $0.id != id }
            let size = grid.size(of: entry.size, at: top, among: [], choices: sizes(of: entry))
            let spots = others.map { GridSpot(size: $0.size, cell: $0.cell(in: grid)) } + [GridSpot(size: size, cell: top)]
            let laid = grid.place(spots, first: others.count)
            guard laid.contains(where: { $0.index == others.count }) else { return .tooLarge }
            let placed = Set(laid.map(\.index))
            let off = others.indices.filter { !placed.contains($0) }.map { others[$0] }
            saveLayout(laid, of: others + [entry], selecting: id, also: { choices in
                choices.set(isOnGrid: true, of: id)
                for spot in off { choices.set(isOnGrid: false, of: spot.id) }
            })
            return .pushed(off: off.map(\.spot.name))
        }
    }

    private func laidGrid() -> (spots: [Entry], placements: [SpotPlacement]) {
        let shown = cards.filter(\.isOnGrid)
        let laid = grid.place(shown.map { GridSpot(size: $0.size, cell: $0.cell(in: grid)) })
        return (laid.map { shown[$0.index] }, laid.enumerated().map { $0.element.reindexed($0.offset) })
    }

    func clearArrange() {
        shelf.reset()
    }

    public func dragShelfSpot(_ id: String, by translation: CGSize) {
        guard isArranging, gesture?.drag == nil, resize == nil, let origin = shelf.origin(of: id) else { return }
        let corner = CGPoint(x: origin.x + translation.width, y: origin.y + translation.height)
        if lift.origin != corner { lift.origin = corner }
        if pin?.id != id {
            guard let entry = shelf.offGrid.first(where: { $0.id == id }) else { return }
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
            guard let target = pin.target, let entry = shelf.offGrid.first(where: { $0.id == pin.id }) else { return moveOnShelf(pin.id, by: translation) }
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
        guard let origin = shelf.origin(of: id), let entry = shelf.spots.first(where: { $0.id == id }),
              let slot = shelf.slot(at: CGPoint(x: origin.x + translation.width, y: origin.y + translation.height), size: entry.size) else { return cancelPin() }
        stopDragWait()
        pointerMove = nil
        change(.edit, {
            gesture = nil
            shelf.lay(placing: (id, slot))
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
