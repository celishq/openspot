import Foundation

extension SpotsModel {
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

    func detachedPlace(of id: String) -> SheetPlace {
        place(ofSheet: id) == .window ? .window : .float
    }

    public func openWindow(_ id: String) {
        guard let entry = cards.first(where: { $0.id == id }) else { return }
        if let sheet = sheets[id], sheet.awaitsAnswer, !runs.floating.contains(id) {
            sheet.afterAnswer { [weak self] in self?.openWindow(id) }
            return
        }
        if !runs.floating.contains(id) { runs.float(id) }
        host.window(entry)
    }

    func readWindows() {
        for id in runs.floating where place(ofSheet: id) == .window { sheets[id]?.read(need: .change) }
    }

    public func land(_ id: String) {
        runs.land(id)
        host.land(id)
    }

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

    public func dropWords(_ paths: [String], on id: String) -> String? {
        guard acceptsDrop(paths, on: id, in: .float), let first = paths.first else { return nil }
        return paths.count == 1 ? "Add \(URL(fileURLWithPath: first).lastPathComponent)" : "Add \(paths.count) files"
    }

    public func pressFloatCard(_ id: String) {
        guard let entry = cards.first(where: { $0.id == id }) else { return }
        switch entry.kind {
        case .toggle, .launch: sheets[id]?.pressCard()
        case .list, .slider, .widget: break
        }
    }
}
