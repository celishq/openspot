import Foundation
import Observation

/// Edit Spots: the order, the size, the letter and the place on the grid of each spot.
extension SpotsModel {
    /// The code of the Delete key, which takes away the letter that records.
    private static let deleteCode: UInt32 = 51

    /// The sizes that a person can prefer for a spot, in words for its menu.
    public func sizes(of entry: Entry) -> [SpotSize] {
        entry.item == nil ? entry.spot.sizes : []
    }

    /// Starts Edit Spots on the grid, with the search cleared.
    public func beginEditing() {
        guard openList == nil else { return }
        closeMenu()
        let folder = files.folder
        change(.edit) {
            query = ""
            isEditing = true
            updateVisible()
            refreshDock(in: folder)
        }
    }

    /// Shows the spots of the dock whose name holds this text.
    public func searchDock(_ text: String) {
        dock.query = text
    }

    /// Takes whether the person types in the dock's search.
    public func searchesDock(_ isOn: Bool) {
        if isSearchingDock != isOn { isSearchingDock = isOn }
    }

    /// Makes the dock from the spots of this folder that are off, and keeps its search.
    func refreshDock(in folder: SpotFolder) {
        let choice = arrangement
        var next = SpotDock(items: Self.offSpots(in: folder).map { SpotDock.Item(spot: $0.spot, isOwn: $0.isOwn, size: choice.size(of: $0.id)) })
        next.query = dock.query
        if next != dock { dock = next }
    }

    /// The core spots of this folder that are not on, and the spots of its files that the person turned off. A sheet that
    /// another spot opens is not one.
    private static func offSpots(in folder: SpotFolder) -> [SpotDock.Item] {
        let own = (try? SpotFolder(url: folder.url).keptScan())?.files ?? []
        let ownIDs = Set(own.map(\.id))
        let core = folder.keptCoreChoices()
            .filter { !folder.enabled.contains(SpotFolder.coreID(of: $0)) && !ownIDs.contains(SpotFolder.coreID(of: $0)) }
        let turnedOff = own.filter { folder.disabled.contains($0.id) }.flatMap(\.spots)
        let opened = Set(turnedOff.compactMap(\.opens))
        return core.map { SpotDock.Item(spot: $0) } + turnedOff.filter { !opened.contains($0.id) }.map { SpotDock.Item(spot: $0, isOwn: true) }
    }

    /// Whether the minus of Edit Spots can turn this spot off. A built-in and a card of faults stay on.
    public func turnsOff(_ entry: Entry) -> Bool {
        entry.item == nil && entry.spot.host == nil && !entry.spot.isBuiltIn && entry.spot.fault == nil
    }

    /// Turns a spot off from Edit Spots: its card leaves the panel, and the dock shows it.
    public func turnOff(_ id: String) {
        guard let entry = visible.first(where: { $0.id == id }), turnsOff(entry) else { return }
        turn(entry.spot, on: false)
    }

    /// Turns a spot of the dock on: its card takes a place in the panel.
    public func turnOn(_ id: String) {
        guard let item = dock.items.first(where: { $0.id == id }) else { return }
        turn(item.spot, on: true)
    }

    /// Moves the file of a spot of the dock to the Trash, as Delete does in the action menu, so `⌘Z` puts it back.
    public func delete(_ id: String) {
        guard let item = dock.items.first(where: { $0.id == id }), item.isOwn else { return }
        remove(Entry(spot: item.spot, run: nil))
    }

    /// Turns a spot on or off in the config, and loads the spots again on the edit motion, after `ending` runs in it.
    @discardableResult
    func turn(_ spot: Spot, on isOn: Bool, ending: () -> Void = {}) -> Bool {
        do {
            try files.config.turn(files.folder.fileID(of: spot), on: isOn)
        } catch {
            host.notify("\(spot.name) was not turned \(isOn ? "on" : "off"). \(Self.reason(error))")
            return false
        }
        change(.edit) {
            ending()
            reload()
        }
        return true
    }

    /// Ends Edit Spots. A panel that closes passes no motion, so that nothing moves during its fade.
    public func endEditing(moving: Bool = true) {
        guard isEditing else { return }
        stopDragWait()
        change(moving ? .edit : nil) {
            isEditing = false
            drag = nil
            landing = nil
            carry = nil
            arrival = nil
            dockResize = nil
            resize = nil
            pointerMove = nil
            if lift.offset != .zero { lift.offset = .zero }
            selected = 0
            isSearchingDock = false
            updateVisible()
        }
    }

    public func handleEditKey(_ key: ActionKey) {
        if isSearchingDock {
            searchDock("")
            isSearchingDock = false
            return
        }
        if drag != nil || resize != nil || carry != nil || dockResize != nil {
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
              let place = SpotGrid().nextPlace(of: selected, in: visible.map(\.size), step: step) else { return }
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
        if let next = SpotGrid().nextSize(of: selected, in: sizes, among: self.sizes(of: entry)) { prefer(next, for: entry.id) }
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

    /// Takes the letter for the spot that records: a letter or a digit with no modifier gives it, and Delete takes its letter
    /// away. A letter that another spot held moves, and a toast names that spot. Any other key leaves it recording, and says
    /// why.
    func recordLetter(code: UInt32, modifiers: Shortcut.Modifiers) {
        guard let id = recording else { return }
        let letter = CommandKey(code: code)
        guard code == Self.deleteCode || (letter != nil && modifiers.isEmpty) else {
            host.notify("Press a letter or a digit with no other key, or Delete to take the letter away.")
            return
        }
        stopRecording()
        arrangement.arrange(visible.map(\.id))
        let holder = arrangement.give(code == Self.deleteCode ? nil : letter, to: id, over: defaultArrangement)
        if let holder, let letter {
            let name = { (spot: String) in self.entries.first { $0.id == spot }?.spot.name ?? spot }
            host.notify("\(letter.name.uppercased()) now runs \(name(id)), so \(name(holder)) has no letter.")
        }
        saveArrangement(selecting: id)
    }

    /// Writes the arrangement, and lays out the cards from it on the edit motion, after `ending` runs in that motion.
    /// `landed` runs when the motion ends.
    func saveArrangement(selecting id: String, ending: () -> Void = {}, landed: @escaping @MainActor () -> Void = {}) {
        do {
            try files.config.write(arrangement)
        } catch {
            host.notify("Openspot could not save the spots. \(Self.reason(error))")
        }
        change(.edit, {
            ending()
            rebuildEntries()
            if let place = visible.firstIndex(where: { $0.id == id }) { selected = place }
            carryHome()
        }, completion: landed)
    }
}
