import Foundation
import Observation

extension SpotsModel {
    private static let deleteCode: UInt32 = 51

    public func sizes(of entry: Entry) -> [SpotSize] {
        entry.item == nil ? entry.spot.sizes : []
    }

    public func beginEditing() {
        guard openList == nil else { return }
        closeMenu()
        change(.edit) {
            query = ""
            isEditing = true
            updateVisible()
        }
    }

    public func editGrid() {
        if openList != nil { closeList(moving: false) }
        host.show()
        beginEditing()
    }

    public func turnsOff(_ entry: Entry) -> Bool {
        entry.item == nil && entry.spot.host == nil && !entry.spot.isBuiltIn && entry.spot.fault == nil
    }

    public func turnOff(_ id: String) {
        guard let entry = visible.first(where: { $0.id == id }), turnsOff(entry) else { return }
        turn(entry.spot, on: false)
    }

    @discardableResult
    func turn(_ spot: Spot, on isOn: Bool, ending: () -> Void = {}) -> Bool {
        let id = folder.fileID(of: spot)
        let next: KeptConfig
        do {
            next = try files.config.change(from: kept) { $0.arrangement.set(isEnabled: isOn, of: id) }
        } catch {
            host.notify("\(spot.name) was not turned \(isOn ? "on" : "off"). \(Self.reason(error))")
            return false
        }
        change(.edit) {
            ending()
            reload(patching: nil, to: next)
        }
        return true
    }

    public func endEditing(moving: Bool = true) {
        guard isEditing else { return }
        stopDragWait()
        change(moving ? .edit : nil) {
            isEditing = false
            tip = nil
            drag = nil
            landing = nil
            carry = nil
            resize = nil
            pointerMove = nil
            if lift.offset != .zero { lift.offset = .zero }
            selected = 0
            updateVisible()
        }
    }

    public func handleEditKey(_ key: ActionKey) {
        if drag != nil || resize != nil || carry != nil {
            if key.name == "escape" {
                cancelDrag()
                cancelResize()
            }
            return
        }
        if openSheet(on: key) { return }
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
        case ("l", _): if let entry = selectedEntry, entry.item == nil { toggleRecording(id: entry.id) }
        default: break
        }
    }

    private func moveSelectedSpot(by step: Int, in order: [String]) {
        guard order.indices.contains(selected),
              let place = grid.nextPlace(of: selected, in: visible.map(\.size), step: step) else { return }
        moveSpot(order[selected], to: place)
    }

    public func moveSpot(_ id: String, to place: Int) {
        var order = visible.map(\.id)
        guard let from = order.firstIndex(of: id), order.indices.contains(place), place != from else { return }
        order.remove(at: from)
        order.insert(id, at: place)
        var next = arrangement
        next.arrange(order)
        saveArrangement(next, selecting: id)
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

    public func prefer(_ size: SpotSize, for id: String) {
        var next = arrangement
        next.arrange(visible.map(\.id))
        next.set(size: size, of: id)
        saveArrangement(next, selecting: id)
    }

    public func setOnGrid(_ isOn: Bool, for id: String) {
        tip = nil
        var next = arrangement
        next.arrange((cards.filter(\.isOnGrid) + cards.filter { !$0.isOnGrid }).map(\.id))
        next.set(isOnGrid: isOn, of: id)
        saveArrangement(next, selecting: id)
    }

    public func show(_ panel: GridPanel, _ isShown: Bool) {
        guard panel.configKey != nil, panels[panel] != isShown, panelLeaving != panel else { return }
        let apply: @MainActor () -> Void = { [self] in
            panelLeaving = nil
            do {
                try write(.panels) { $0.show(panel, isShown) }
            } catch {
                return host.notify("Openspot could not save the panels. \(Self.reason(error))")
            }
            if panels[panel] != isShown { panels[panel] = isShown }
            updateVisible()
        }
        let held = cards.filter { $0.panel == panel }.map(\.id)
        guard !held.isEmpty else { return apply() }
        let leaving = isShown ? [] : cards.filter { $0.isOnGrid && $0.panel == panel }.map(\.id)
        var next = arrangement
        held.forEach { next.set(panel: .center, of: $0) }
        guard let first = leaving.first else {
            guard save(next) else { return }
            rebuildEntries()
            return apply()
        }
        let onGrid = cards.filter(\.isOnGrid).map(\.id).filter { !leaving.contains($0) }
        next.arrange(onGrid + leaving + cards.filter { !$0.isOnGrid }.map(\.id))
        guard save(next) else { return }
        panelLeaving = panel
        land(selecting: first, landed: apply)
    }

    func recordLetter(code: UInt32, modifiers: Shortcut.Modifiers) {
        guard let id = recording else { return }
        let letter = CommandKey(code: code)
        guard code == Self.deleteCode || (letter != nil && modifiers.isEmpty) else {
            host.notify("Press a letter or a digit with no other key, or Delete to take the letter away.")
            return
        }
        stopRecording()
        var next = arrangement
        next.arrange(visible.map(\.id))
        let holder = next.give(code == Self.deleteCode ? nil : letter, to: id, over: defaultArrangement)
        guard save(next) else { return }
        if let holder, let letter {
            let name = { (spot: String) in self.entries.first { $0.id == spot }?.spot.name ?? spot }
            host.notify("\(letter.name.uppercased()) now runs \(name(id)), so \(name(holder)) has no letter.")
        }
        land(selecting: id)
    }

    func saveArrangement(_ next: SpotArrangement, selecting id: String, ending: () -> Void = {}, landed: @escaping @MainActor () -> Void = {}) {
        save(next)
        land(selecting: id, ending: ending, landed: landed)
    }

    @discardableResult
    private func save(_ next: SpotArrangement) -> Bool {
        do {
            try write(.spots) { $0.arrangement = next }
            return true
        } catch {
            host.notify("Openspot could not save the spots. \(Self.reason(error))")
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
