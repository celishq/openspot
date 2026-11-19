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
        guard let entry = card(id: id) else { return }
        if let sheet = sheets[id], sheet.awaitsAnswer, !runs.floating.contains(id) {
            sheet.afterAnswer { [weak self] in self?.openWindow(id) }
            return
        }
        if runs.floating.contains(id) {
            sheets[id]?.read(need: .change)
        } else {
            runs.float(id)
        }
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
        for row in floatRows(of: sheet, id) where row.takes(key) {
            if let handled = row.act(key) { return handled }
        }
        return false
    }

    private func floatRows(of sheet: SpotRun, _ id: String) -> [KeyRow] {
        let item = sheet.selectedItem
        let entry = card(id: id)
        let move = { (step: Int) -> @MainActor (ActionKey) -> Bool? in
            { _ in
                sheet.list.move(by: step)
                return true
            }
        }
        return [
            .any { key in
                guard let part = sheet.panel?.parts.first(where: { $0.key == key }) else { return nil }
                sheet.press(part)
                return true
            },
            .any { [self] key in
                guard let entry, let action = sheet.spot.actions(for: item).first(where: { $0.key == key }) else { return nil }
                run(action, on: (entry, item), in: detachedPlace(of: id))
                return true
            },
            KeyRow("escape") { [self] _ in
                land(id)
                return true
            },
            KeyRow("up", act: move(-1)),
            KeyRow("down", act: move(1)),
            KeyRow("return") { [self] _ in
                guard let item, let entry else { return false }
                pick(item, of: entry, in: detachedPlace(of: id))
                return true
            },
        ]
    }

    public func dropWords(_ paths: [String], on id: String) -> String? {
        guard acceptsDrop(paths, on: id, in: .float), let first = paths.first else { return nil }
        return paths.count == 1 ? "Add \(URL(fileURLWithPath: first).lastPathComponent)" : "Add \(paths.count) files"
    }

    public func pressFloatCard(_ id: String) {
        guard let entry = card(id: id) else { return }
        switch entry.kind {
        case .toggle, .launch: sheets[id]?.pressCard()
        case .list, .slider, .widget: break
        }
    }
}
