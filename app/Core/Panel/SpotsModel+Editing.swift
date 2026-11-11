import Foundation
import Observation

/// Edit Spots: the order, the size, the letter and the place on the grid of each spot.
extension SpotsModel {
    /// The code of the Delete key, which takes away the letter that records.
    private static let deleteCode: UInt32 = 51

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
        change(moving ? .edit : nil) {
            isEditing = false
            selected = 0
            updateVisible()
        }
    }

    public func handleEditKey(_ key: ActionKey) {
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
            let name = { (spot: String) in self.entries.first { $0.id == spot }?.command.name ?? spot }
            host.notify("\(letter.name.uppercased()) now runs \(name(id)), so \(name(holder)) has no letter.")
        }
        saveArrangement(selecting: id)
    }

    private func saveArrangement(selecting id: String) {
        do {
            try files.config.write(arrangement)
        } catch {
            host.notify("Openspot could not save the spots. \(Self.reason(error))")
        }
        change(.edit) {
            rebuildEntries()
            if let place = visible.firstIndex(where: { $0.id == id }) { selected = place }
        }
    }
}
