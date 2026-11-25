import Foundation
import Observation

extension SpotsModel {

    public func sizes(of entry: Entry) -> [SpotSize] {
        entry.item == nil ? SpotSize.all : [entry.size]
    }

    public func beginEditing() {
        begin(.open)
    }

    private func begin(_ session: EditSession) {
        asOnePress {
            guard openSheetID == nil else { return }
            closeMenu()
            missedSearch.drop()
            hold(nil)
            change(.edit) {
                editing = session
                query = ""
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

    public func turnsOff(_ entry: Entry) -> Bool {
        entry.item == nil && entry.spot.host == nil && !entry.spot.isBuiltIn && entry.spot.fault == nil
    }

    public func turnOff(_ id: String) {
        asOnePress {
            guard let entry = visible.first(where: { $0.id == id }), turnsOff(entry) else { return }
            turn(entry.spot, on: false)
        }
    }

    @discardableResult
    func turn(_ spot: Spot, on isOn: Bool, ending: () -> Void = {}) -> Bool {
        let id = folder.fileID(of: spot)
        let next: KeptConfig
        do {
            next = try files.config.change(from: kept) { $0.arrangement.set(isEnabled: isOn, of: id) }
        } catch {
            toast(.failure("\(spot.name) was not turned \(isOn ? "on" : "off"). \(Self.reason(error))"))
            return false
        }
        change(.edit) {
            ending()
            reload(patching: nil, to: next)
        }
        return true
    }

    public func endEditing(moving: Bool = true) {
        asOnePress {
            guard isEditing else { return }
            stopDragWait()
            change(moving ? .edit : nil) {
                editing = nil
                tip = nil
                gesture = nil
                landing = nil
                carry = nil
                pointerMove = nil
                if lift.offset != .zero { lift.offset = .zero }
                selected = 0
                updateVisible()
            }
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

    func saveLayout(_ layout: [SpotPlacement], selecting id: String, ending: () -> Void = {}, landed: @escaping @MainActor () -> Void = {}, also: (inout SpotChoices) -> Void = { _ in }) {
        let count = grid.columns
        let changes = layout.filter { visible.indices.contains($0.index) }.map { (visible[$0.index], $0) }
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
