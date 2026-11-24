import Foundation
import Observation

extension SpotsModel {

    public func sizes(of entry: Entry) -> [SpotSize] {
        entry.item == nil ? SpotSize.all : []
    }

    public func beginEditing() {
        asOnePress {
            guard openSheetID == nil else { return }
            closeMenu()
            missedSearch.drop()
            hold(nil, motion: .edit)
            change(.edit) {
                isEditing = true
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
        asOnePress {
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
    }

    func moveSelectedSpot(by step: Int) {
        let order = visible.map(\.id)
        guard order.indices.contains(selected),
              let place = grid.nextPlace(of: selected, in: visible.map(\.size), step: step) else { return }
        moveSpot(order[selected], to: place)
    }

    public func moveSpot(_ id: String, to place: Int) {
        var order = visible.map(\.id)
        guard let from = order.firstIndex(of: id), order.indices.contains(place), place != from else { return }
        order.remove(at: from)
        order.insert(id, at: place)
        saveArrangement({ $0.arrange(order) }, selecting: id)
    }

    func stepSelectedSize() {
        guard let entry = selectedEntry else { return }
        let sizes = visible.map(\.size)
        if let next = grid.nextSize(of: selected, in: sizes, among: self.sizes(of: entry)) { prefer(next, for: entry.id) }
    }

    func toggleSelectedOnGrid() {
        guard let entry = selectedEntry else { return }
        setOnGrid(!entry.isOnGrid, for: entry.id)
    }

    public func prefer(_ size: SpotSize, for id: String) {
        let order = visible.map(\.id)
        saveArrangement({
            $0.arrange(order)
            $0.set(size: size, of: id)
        }, selecting: id)
    }

    public func setOnGrid(_ isOn: Bool, for id: String) {
        tip = nil
        let order = (cards.filter(\.isOnGrid) + cards.filter { !$0.isOnGrid }).map(\.id)
        saveArrangement({
            $0.arrange(order)
            $0.set(isOnGrid: isOn, of: id)
        }, selecting: id)
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
        guard let first = leaving.first else {
            guard save({ next in held.forEach { next.set(panel: .center, of: $0) } }) else { return }
            rebuildEntries()
            return apply()
        }
        let onGrid = cards.filter(\.isOnGrid).map(\.id).filter { !leaving.contains($0) }
        let order = onGrid + leaving + cards.filter { !$0.isOnGrid }.map(\.id)
        let isSaved = save { next in
            held.forEach { next.set(panel: .center, of: $0) }
            next.arrange(order)
        }
        guard isSaved else { return }
        panelLeaving = panel
        land(selecting: first, landed: apply)
    }


    func saveArrangement(_ edit: (inout SpotArrangement) -> Void, selecting id: String, ending: () -> Void = {}, landed: @escaping @MainActor () -> Void = {}) {
        save(edit)
        land(selecting: id, ending: ending, landed: landed)
    }

    @discardableResult
    private func save(_ edit: (inout SpotArrangement) -> Void) -> Bool {
        do {
            try write(.spots) { edit(&$0.arrangement) }
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
