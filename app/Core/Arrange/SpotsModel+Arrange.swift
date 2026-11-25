import Foundation

extension SpotsModel {
    public func arrange() {
        beginEditing()
    }

    public func arranges(_ entry: Entry) -> Bool {
        takesOffGrid(entry) && !entry.spot.isSource
    }

    public func searchShelf(_ text: String) {
        asOnePress {
            guard text != arrangeQuery else { return }
            arrangeQuery = text
            takeShelf()
        }
    }

    public func shelfScrolled(to offset: CGFloat) {
        guard arrangeScroll != offset else { return }
        arrangeScroll = offset
    }

    func takeOffGridSpots(placed: Set<String>) {
        let next = cards
            .filter { !placed.contains($0.id) && arranges($0) }
            .sorted { $0.spot.name.localizedStandardCompare($1.spot.name) == .orderedAscending }
        guard next != offGrid else { return }
        offGrid = next
        offGridWords = next.map { Self.fold(([$0.spot.name] + $0.spot.keywords).joined(separator: " ")) }
        shelfNames = Dictionary(next.map { ($0.id, ShelfName($0.spot.name)) }, uniquingKeysWith: { first, _ in first })
        takeShelf()
    }

    func takeShelf() {
        let next = shelfMatches(of: arrangeQuery)
        if next != shelf { shelf = next }
    }

    func shelfMatches(of text: String) -> [Entry] {
        let words = Self.fold(text.trimmingCharacters(in: .whitespaces))
        return words.isEmpty ? offGrid : zip(offGrid, offGridWords).filter { $0.1.contains(words) }.map(\.0)
    }

    public func gridSpots() -> [ArrangedSpot] {
        let placed = Set(laidGrid().spots.map(\.id))
        let spots = cards.filter(arranges).sorted { $0.spot.name.localizedStandardCompare($1.spot.name) == .orderedAscending }
        let listed = { (entry: Entry) in
            ArrangedSpot(id: entry.id, name: entry.spot.name, icon: entry.spot.image ?? entry.spot.file ?? entry.spot.glyph ?? entry.spot.symbol, isOnGrid: placed.contains(entry.id))
        }
        return spots.filter { !placed.contains($0.id) }.map(listed) + spots.filter { placed.contains($0.id) }.map(listed)
    }

    private func laidGrid() -> (spots: [Entry], placements: [SpotPlacement]) {
        let shown = cards.filter(\.isOnGrid)
        let laid = grid.place(shown.map { GridSpot(size: $0.size, cell: $0.cell(in: grid)) })
        return (laid.map { shown[$0.index] }, laid.enumerated().map { $0.element.reindexed($0.offset) })
    }

    func clearArrange() {
        if !arrangeQuery.isEmpty { arrangeQuery = "" }
        arrangeScroll = 0
        takeShelf()
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    public func dragShelfSpot(_ id: String, from origin: CGPoint, by translation: CGSize) {
        guard isArranging, gesture?.drag == nil, resize == nil else { return }
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
        guard let pin, case let next = pin.moved(by: translation), next != pin else { return }
        change(.edit) {
            gesture = .pin(next)
            if carry?.size != next.carriedSize { carry?.size = next.carriedSize }
        }
    }

    public func dropShelfSpot(by translation: CGSize) {
        asOnePress {
            guard let pin = pin?.moved(by: translation) else { return }
            guard let target = pin.target, let entry = offGrid.first(where: { $0.id == pin.id }) else { return cancelPin() }
            var spots = visible
            var layout = placements
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

    func cancelPin() {
        guard pin != nil else { return }
        change(.edit) {
            gesture = nil
            carry = nil
        }
    }

    @discardableResult
    public func pin(_ id: String, at cell: GridCell? = nil) -> GridPin {
        asOnePress {
            guard let entry = card(id: id), arranges(entry) else { return .unknown }
            let (spots, layout) = laidGrid()
            guard !spots.contains(where: { $0.id == id }) else { return .onGrid }
            let choices = sizes(of: entry)
            let slots = cell.map { [$0] } ?? grid.freeCells(around: layout)
            guard let slot = slots.lazy.compactMap({ slot in self.grid.fit(entry.size, at: slot, among: layout, choices: choices).map { (slot, $0) } }).first else { return .full }
            let placement = SpotPlacement(index: spots.count, row: slot.0.row, column: slot.0.column, size: slot.1)
            saveLayout(layout + [placement], of: spots + [entry], selecting: id, also: { $0.set(isOnGrid: true, of: id) })
            return .pinned(slot.0)
        }
    }
}
