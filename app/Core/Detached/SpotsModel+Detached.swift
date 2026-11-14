import Foundation

/// The sheets outside the panel: floats at the pointer (W1–W9), and windows of spots that offer one (W10).
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
        host.float(entry, followsDrag: host.isMouseDown)
    }

    /// The place of a sheet that shows outside the panel: its window, or else its float.
    func detachedPlace(of id: String) -> SheetPlace {
        place(ofSheet: id) == .window ? .window : .float
    }

    /// Opens the sheet of a spot that offers a window in its window, and puts the panel away. A spot whose window shows
    /// comes to the front. A spot whose kind comes from its first answer opens once that answer arrives.
    public func openWindow(_ id: String) {
        guard let entry = cards.first(where: { $0.id == id }) else { return }
        if isShown { host.dismiss() }
        if let sheet = sheets[id], sheet.awaitsAnswer, !runs.floating.contains(id) {
            sheet.afterAnswer { [weak self] in self?.openWindow(id) }
            return
        }
        if !runs.floating.contains(id) { runs.float(id) }
        host.window(entry)
    }

    /// Closes the float or the window of a spot.
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
        if let action = sheet.spot.actions(for: item).first(where: { $0.key == key }), let entry = cards.first(where: { $0.id == id }) {
            run(action, on: (entry, item), in: detachedPlace(of: id))
            return true
        }
        switch key {
        case ActionKey(name: "escape"): land(id)
        case ActionKey(name: "up"): sheet.list.move(by: -1)
        case ActionKey(name: "down"): sheet.list.move(by: 1)
        case ActionKey(name: "return"):
            guard let item, let entry = cards.first(where: { $0.id == id }) else { return false }
            pick(item, of: entry, in: detachedPlace(of: id))
        default: return false
        }
        return true
    }

    /// What a drop of these files on a float adds, while the float takes them (W9).
    public func dropWords(_ paths: [String], on id: String) -> String? {
        guard acceptsDrop(paths, on: id, in: .float), let first = paths.first else { return nil }
        return paths.count == 1 ? "Add \(URL(fileURLWithPath: first).lastPathComponent)" : "Add \(paths.count) files"
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
