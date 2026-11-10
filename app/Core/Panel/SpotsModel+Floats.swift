import Foundation

/// The floats: spots that show in windows of their own at the pointer, apart from the panel (W1–W9).
extension SpotsModel {
    /// Floats a spot, or closes its float when it floats. While a drag holds the mouse button, it brings the float to the
    /// pointer instead, where the drag needs it (W6). A spot whose kind comes from its first answer floats once that answer
    /// arrives.
    public func float(_ id: String) {
        guard let entry = cards.first(where: { $0.id == id && $0.kind != .widget }) else { return }
        if runs.floating.contains(id), !host.isMouseDown {
            land(id)
            return
        }
        if let sheet = sheets[id], sheet.awaitsAnswer, !runs.floating.contains(id) {
            sheet.afterAnswer { [weak self] in self?.float(id) }
            return
        }
        runs.float(id)
        host.float(entry)
    }

    /// Closes the float of a spot.
    public func land(_ id: String) {
        runs.land(id)
        host.land(id)
    }

    /// Takes a key of a float: the key of a part or of an action, Esc, Up, Down and Return (W8). Returns false for any other
    /// key, and for a spot that does not float.
    public func handleFloatKey(_ key: ActionKey, in id: String) -> Bool {
        guard runs.floating.contains(id), let sheet = sheets[id] else { return false }
        let item = sheet.selectedItem
        if let part = sheet.panel?.parts.first(where: { $0.key == key }) {
            sheet.press(part)
            return true
        }
        if let action = sheet.command.actions(for: item).first(where: { $0.key == key }) {
            runInFloat(action, of: id, item: item)
            return true
        }
        switch key {
        case ActionKey(name: "escape"): land(id)
        case ActionKey(name: "up"): sheet.list.move(by: -1)
        case ActionKey(name: "down"): sheet.list.move(by: 1)
        case ActionKey(name: "return"):
            guard let item else { return false }
            pickInFloat(item, of: id)
        default: return false
        }
        return true
    }

    /// Runs an action of a float on a row, or on the whole spot. One that asks with a form or for a second press opens the
    /// spot in the panel, where both work (W8).
    public func runInFloat(_ action: CommandAction, of id: String, item: SpotItem?) {
        guard let sheet = sheets[id] else { return }
        if action.isForm || action.confirm != nil {
            press(id)
        } else {
            sheet.run(action, item: item)
        }
    }

    /// Runs a pick of a row of a float, which stays open with the picked row selected (W8). A pick that asks with a form or
    /// records a key opens the spot in the panel.
    public func pickInFloat(_ item: SpotItem, of id: String) {
        guard let sheet = sheets[id] else { return }
        if sheet.command.pickForm != nil || item.shortcut != nil {
            press(id)
            return
        }
        if sheet.command.keepsRecent {
            sheet.list.remember(item)
            sheet.list.select(run: item.run)
            files.remember(sheet.list.recent, of: id)
        }
        sheet.pick(item)
    }

    /// Whether a float takes these dragged files, as its card would (W9).
    public func floatAccepts(_ paths: [String], of id: String) -> Bool {
        runs.floating.contains(id) && !SharedSpot.isFile(paths) && sheets[id]?.command.accepts(paths) == true
    }

    /// Takes a drop on a float as a drop on its card, and leaves the panel and the float as they are (W9). Returns false when
    /// the float does not take these files.
    public func dropOnFloat(_ paths: [String], of id: String) -> Bool {
        guard floatAccepts(paths, of: id) else { return false }
        return sheets[id]?.drop(paths) == true
    }

    /// Sends a change, or with no value a press, of a slot of a row of a float (U9).
    public func slotInFloat(_ slot: String, of item: SpotItem, in id: String, to value: String?) {
        if let value { sheets[id]?.set(slot: slot, of: item, to: value) } else { sheets[id]?.press(slot: slot, of: item) }
    }

    /// Runs a press of a float's card, as a press on the grid does, and leaves the panel as it is.
    public func pressFloatCard(_ id: String) {
        guard let entry = cards.first(where: { $0.id == id }) else { return }
        switch entry.kind {
        case .toggle, .launch: sheets[id]?.pressCard()
        case .list, .slider, .widget: break
        }
    }
}
