import Foundation
import Observation

extension SpotsModel {

    public func sizes(of entry: Entry) -> [SpotSize] {
        entry.item == nil ? SpotSize.all : [entry.size]
    }

    public func beginEditing() {
        begin(.arrange)
    }

    private func begin(_ session: EditSession) {
        asOnePress {
            guard openSheetID == nil else { return }
            closeMenu()
            missedSearch.drop()
            showDetails(nil)
            if session == .arrange { host.arrange(true) }
            change(.edit) {
                editing = session
                query = ""
                clearArrange()
                updateVisible()
            }
            hideAttachments()
        }
    }

    public func editGrid() {
        if openSheetID != nil { closeSheet(moving: false) }
        host.show()
        beginEditing()
    }

    func editByKey() {
        guard command == .held, !isEditing, openSheetID == nil, menu == nil, form == nil, recording == nil,
              query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        begin(.held)
    }

    func holdCommand(_ isHeld: Bool) {
        guard isHeld != (command != .up) else { return }
        command = isHeld ? .held : .up
        if !isHeld { endKeyEditing() }
    }

    func spoilCommand(by key: ActionKey) {
        guard key.isCommand, command != .up else { return }
        command = .spoiled
        guard editing == .held else { return }
        if gesture != nil { dropGesture() }
        endEditing(moving: false)
    }

    func endKeyEditing() {
        guard editing == .held, command == .up, gesture == nil, landing == nil else { return }
        endEditing()
    }

    public func takesOffGrid(_ entry: Entry) -> Bool {
        entry.item == nil && entry.spot.host == nil && entry.spot.fault == nil && !entry.spot.isDraft
    }

    public func takeOffGrid(_ id: String, to slot: ShelfSlot? = nil) {
        asOnePress {
            guard let entry = visible.first(where: { $0.id == id }), takesOffGrid(entry) else { return }
            let next: KeptConfig
            do {
                next = try files.config.change(from: kept) { $0.arrangement.set(isOnGrid: false, of: id) }
            } catch {
                if carry != nil { change(.edit) { carry = nil } }
                return toast(.failure("\(entry.spot.name) stays on the grid. \(Self.reason(error))"))
            }
            change(.edit, {
                reload(patching: nil, to: next)
                if let slot { shelf.lay(placing: (id, slot)) }
                carryToShelf()
            }, completion: { self.endLanding(of: id) })
        }
    }

    public func endEditing(moving: Bool = true) {
        asOnePress {
            guard isEditing else { return }
            stopDragWait()
            let wasArranging = isArranging
            change(moving ? .edit : nil, {
                editing = nil
                tip = nil
                gesture = nil
                landing = nil
                carry = nil
                pointerMove = nil
                if lift.offset != .zero { lift.offset = .zero }
                selected = 0
                clearArrange()
                updateVisible()
            }, completion: { [self] in
                if wasArranging, !isArranging { host.arrange(false) }
            })
        }
    }

    func moveSelectedSpot(dx: Int, dy: Int) {
        guard placements.indices.contains(selected), let entry = selectedEntry else { return }
        let here = placements[selected]
        moveSpot(entry.id, to: GridCell(row: here.row + dy, column: here.column + dx))
    }

    public func moveSpot(_ id: String, to cell: GridCell) {
        guard let index = visible.firstIndex(where: { $0.id == id }), placements.indices.contains(index),
              let layout = grid.moved(index, to: cell, size: placements[index].size, in: placements),
              layout != placements else { return }
        saveLayout(layout, selecting: id)
    }

    func stepSelectedSize() {
        guard let entry = selectedEntry, placements.indices.contains(selected) else { return }
        let choices = sizes(of: entry)
        let here = placements[selected]
        let start = choices.firstIndex(of: here.size) ?? -1
        let next = (1..<max(choices.count, 1)).lazy
            .map { choices[(start + $0 + choices.count) % choices.count] }
            .compactMap { self.grid.moved(self.selected, to: here.cell, size: $0, in: self.placements) }
            .first
        if let next { saveLayout(next, selecting: entry.id) }
    }

    public func prefer(_ size: SpotSize, for id: String) {
        guard let index = visible.firstIndex(where: { $0.id == id }), placements.indices.contains(index),
              let layout = grid.moved(index, to: placements[index].cell, size: size, in: placements) else { return }
        saveLayout(layout, selecting: id, also: { $0.set(size: size, of: id) })
    }

    public func set(columns: Int) {
        asOnePress {
            let next = GridLayout(columns: columns)
            guard next != grid else { return }
            do {
                try write(.columns) { $0.set(columns: columns) }
            } catch {
                return toast(.failure("Openspot could not save the columns. \(Self.reason(error))"))
            }
            grid = next
            if !visible.indices.contains(selected) { selected = 0 }
        }
    }

    func saveLayout(_ layout: [SpotPlacement], of spots: [Entry]? = nil, selecting id: String, ending: () -> Void = {}, landed: @escaping @MainActor () -> Void = {}, also: (inout SpotChoices) -> Void = { _ in }) {
        let count = grid.columns
        let spots = spots ?? visible
        let changes = layout.filter { spots.indices.contains($0.index) }.map { (spots[$0.index], $0) }
        save { next in
            for (entry, placement) in changes {
                if entry.cell(in: grid) != placement.cell { next.set(cell: placement.cell, of: entry.id, columns: count) }
                if entry.size != placement.size { next.set(size: placement.size, of: entry.id) }
            }
            also(&next)
        }
        land(selecting: id, ending: ending, landed: landed)
    }

    @discardableResult
    private func save(_ edit: (inout SpotChoices) -> Void) -> Bool {
        do {
            try write(.spots) { edit(&$0.arrangement) }
            return true
        } catch {
            toast(.failure("Openspot could not save the spots. \(Self.reason(error))"))
            return false
        }
    }

    private func land(selecting id: String, ending: () -> Void = {}, landed: @escaping @MainActor () -> Void = {}) {
        change(.edit, {
            ending()
            rebuildEntries()
            if let place = visible.firstIndex(where: { $0.id == id }) { selected = place }
            carryHome()
        }, completion: landed)
    }
}
