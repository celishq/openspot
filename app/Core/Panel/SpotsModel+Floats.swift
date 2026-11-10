import Foundation

/// The floats: spots that show in windows of their own at the pointer, apart from the panel (W1–W9).
extension SpotsModel {
    /// Floats a spot, or brings its float to the pointer when it floats (W6). A spot whose kind comes from its first answer
    /// floats once that answer arrives.
    public func float(_ id: String) {
        guard let entry = cards.first(where: { $0.id == id && $0.kind != .widget }) else { return }
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

    /// Runs a pick of a row of a float, which stays open (W8). A pick that asks with a form or records a key opens the spot
    /// in the panel.
    public func pickInFloat(_ item: SpotItem, of id: String) {
        guard let sheet = sheets[id] else { return }
        if sheet.command.pickForm != nil || item.shortcut != nil {
            press(id)
            return
        }
        if sheet.command.keepsRecent {
            sheet.list.remember(item)
            files.remember(sheet.list.recent, of: id)
        }
        sheet.pick(item)
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
