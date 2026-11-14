import Foundation

/// The history of the panel: a page or a spot that opens over the sheet that shows, and the keys that move back, forward
/// and to the grid.
extension SpotsModel {
    static let backKey = ActionKey(name: "[", isCommand: true)
    static let forwardKey = ActionKey(name: "]", isCommand: true)
    static let gridKey = ActionKey(name: "escape", isCommand: true)

    /// Opens a page of a spot as the newest sheet of the history: in the panel that shows, or else in the panel that it
    /// shows. Returns false when no spot has that ID.
    public func openSheet(_ id: String, page: String) -> Bool {
        guard entries.contains(where: { $0.id == id }) else { return false }
        let moves = isShown
        if !moves { host.show() }
        endEditing(moving: false)
        if openList == nil { closeHistory() }
        let next = SheetPage(spot: id, page: page)
        history.push(next)
        show(next, moving: moves, from: 1)
        return true
    }

    /// Shows the sheet before in the history. Returns false when there is none.
    @discardableResult
    public func goBack() -> Bool {
        guard openList != nil, let page = history.back() else { return false }
        show(page, moving: isShown, from: -1)
        return true
    }

    /// Shows the sheet after in the history. Returns false when there is none.
    @discardableResult
    public func goForward() -> Bool {
        guard openList != nil, let page = history.forward() else { return false }
        show(page, moving: isShown, from: 1)
        return true
    }

    /// Takes ⌘[, ⌘] and ⌘Esc while a sheet shows. Returns nil for any other key.
    func handleHistoryKey(_ key: ActionKey) -> Bool? {
        switch key {
        case Self.backKey: goBack()
        case Self.forwardKey: goForward()
        case Self.gridKey: closeList(moving: isShown)
        default: return nil
        }
        return true
    }

    /// Shows a sheet of the history: its page in its run, in the place of the sheet that shows. Another page of the sheet
    /// that shows slides in from `side`, -1 for the left and 1 for the right, when it moves. A spot that left the folder
    /// leaves the history, which then shows the page at its centre, or closes when it is empty.
    private func show(_ page: SheetPage, moving: Bool, from side: Double) {
        guard let sheet = sheets[page.spot] else {
            history.remove(spot: page.spot)
            if let current = history.current { show(current, moving: moving, from: side) } else { closeList(moving: moving) }
            return
        }
        guard openList == page.spot else {
            sheet.show(page: page.page)
            return present(page.spot, moving: moving)
        }
        guard moving, sheet.page != page.page else { return sheet.show(page: page.page) }
        change(nil) {
            sheet.show(page: page.page)
            slideOffset = side * MotionTokens.slideDistance
        }
        DispatchQueue.main.async { [weak self] in
            self?.change(.slide) { self?.slideOffset = 0 }
        }
    }

    /// Brings each spot of the history back to its first sheet, and empties the history.
    func closeHistory() {
        for page in history.pages where page.page != nil { sheets[page.spot]?.show(page: nil) }
        history.clear()
    }
}
