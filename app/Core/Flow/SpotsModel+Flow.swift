import Foundation

/// The flow of the panel: a page or a spot that opens over the sheet that shows, and the keys that move back, forward
/// and to the grid.
extension SpotsModel {
    static let backKey = ActionKey(name: "[", isCommand: true)
    static let forwardKey = ActionKey(name: "]", isCommand: true)
    static let gridKey = ActionKey(name: "escape", isCommand: true)

    /// Opens a page of a spot as the newest sheet of the flow: in the panel that shows, or else in the panel that it
    /// shows. With no title, the page takes the title of the row of that spot that opens it, when the spot shows one.
    /// Returns false when no spot has that ID.
    public func openSheet(_ id: String, page: String, title: String? = nil) -> Bool {
        guard let spot = entries.first(where: { $0.id == id })?.spot else { return false }
        guard spot.takes(page: page) else {
            host.notify("\(spot.name) takes no page \(page). Add pages=\(page) to its header")
            return true
        }
        let moves = isShown
        if !moves { host.show() }
        endEditing(moving: false)
        if openList == nil { endFlow() }
        let next = FlowSheet(spot: id, page: page, title: title ?? sheets[id]?.list.all.first { $0.run == page }?.title)
        flow.push(next)
        show(next, moving: moves, from: 1)
        return true
    }

    /// Opens the first sheet of a spot as a new flow, with nothing behind it: in the panel that shows, or else in the panel
    /// that it shows. Returns false when no spot has that ID.
    public func openFlow(_ id: String) -> Bool {
        guard entries.contains(where: { $0.id == id }) else { return false }
        endFlow()
        return openSheet(id)
    }

    /// Pushes a sheet of a spot over the flow that shows, as `openspot spot push` asks: in the panel that shows, or else in
    /// the panel that it shows. Returns false when no spot has that ID.
    public func pushSheet(_ id: String, page: String?, title: String?, replace: Bool) -> Bool {
        guard entries.contains(where: { $0.id == id }) else { return false }
        if !isShown { host.show() }
        push(id, page: page, title: title, replace: replace)
        return true
    }

    /// Shows the sheet some steps before in the flow. Returns false when that many do not lie behind.
    @discardableResult
    public func goBack(steps: Int = 1) -> Bool {
        guard openList != nil, let page = flow.back(steps: steps) else { return false }
        show(page, moving: isShown, from: -1)
        return true
    }

    /// Shows the sheet after in the flow. Returns false when there is none.
    @discardableResult
    public func goForward() -> Bool {
        guard openList != nil, let page = flow.forward() else { return false }
        show(page, moving: isShown, from: 1)
        return true
    }

    /// Pops the sheet of a spot that shows: back to the sheet before it, a page of the spot or the sheet that pushed it.
    /// Returns false when the spot does not show or nothing lies behind, since a spot never closes the panel.
    @discardableResult
    public func pop(in id: String) -> Bool {
        guard openList == id, flow.current?.spot == id, flow.behind != nil else { return false }
        return goBack()
    }

    /// Shows the first sheet of the spot that shows, back through its own pages only. Returns false when none lies behind.
    @discardableResult
    public func goFirst(in id: String) -> Bool {
        guard openList == id else { return false }
        var start = flow.index
        while start > 0, flow.pages[start].page != nil, flow.pages[start - 1].spot == id { start -= 1 }
        return start < flow.index && goBack(steps: flow.index - start)
    }

    /// Moves the flow of the spot that shows, as a `push` or `pop` effect of its press asks (protocol: Pages). A spot that
    /// does not show moves nothing.
    func move(_ move: FlowMove, in id: String) {
        guard openList == id else { return }
        switch move {
        case .pop(let all): all ? goFirst(in: id) : pop(in: id)
        case .push(let spot, let page, let title, let replace): push(spot ?? id, page: page, title: title, replace: replace)
        }
    }

    /// Pushes a sheet of a spot over the sheet that shows: its first sheet, or a page. With `replace`, it takes the place of
    /// the sheet that shows. A spot with no sheet gets the call `<spot> open <page>` instead.
    func push(_ id: String, page: String?, title: String?, replace: Bool) {
        guard opensSheet(id) else {
            sheets[id]?.pick(SpotItem(title: title ?? page ?? id, run: page ?? ""))
            return
        }
        let next = FlowSheet(spot: id, page: page, title: title)
        guard replace, flow.current != nil else {
            if let page { _ = openSheet(id, page: page, title: title) } else { open(id, moving: isShown, title: title) }
            return
        }
        flow.replaceCurrent(with: next)
        show(next, moving: isShown, from: 1)
    }

    /// Whether the spot has a sheet that a push can show.
    func opensSheet(_ id: String) -> Bool {
        entries.first { $0.id == id }?.kind.opensSheet == true
    }

    /// Takes ⌘[, ⌘] and ⌘Esc while a sheet shows. Returns nil for any other key.
    func handleFlowKey(_ key: ActionKey) -> Bool? {
        switch key {
        case Self.backKey: goBack()
        case Self.forwardKey: goForward()
        case Self.gridKey: closeList(moving: isShown)
        default: return nil
        }
        return true
    }

    /// Shows a sheet of the flow: its page in its run, in the place of the sheet that shows. Another page of the sheet
    /// that shows slides in from `side`, -1 for the left and 1 for the right, when it moves. A spot that left the folder
    /// leaves the flow, which then shows the page at its centre, or closes when it is empty.
    private func show(_ page: FlowSheet, moving: Bool, from side: Double) {
        guard let sheet = sheets[page.spot] else {
            flow.remove(spot: page.spot)
            if let current = flow.current { show(current, moving: moving, from: side) } else { closeList(moving: moving) }
            return
        }
        guard openList == page.spot else {
            sheet.show(page: page.page)
            pendingPush = moving ? side : nil
            return present(page.spot, moving: moving)
        }
        guard moving, sheet.page != page.page else { return sheet.show(page: page.page) }
        change(nil) {
            sheet.show(page: page.page)
            pushOffset = side * MotionTokens.pushDistance
        }
        settlePush()
    }

    /// Takes the side of a push that waits for its sheet, and lays the content there for this turn.
    func startPendingPush() {
        guard let side = pendingPush else { return }
        pendingPush = nil
        pushOffset = side * MotionTokens.pushDistance
    }

    /// Moves the content of the sheet to its place on the next turn, so that the push has a start.
    func settlePush() {
        DispatchQueue.main.async { [weak self] in
            self?.change(.push) { self?.pushOffset = 0 }
        }
    }

    /// Brings each spot of the flow back to its first sheet, and empties the flow.
    func endFlow() {
        for page in flow.pages where page.page != nil { sheets[page.spot]?.show(page: nil) }
        flow.clear()
    }

    /// The title of a sheet of the flow: its own, or else the name of its spot for a first sheet, or else its page.
    func title(of sheet: FlowSheet) -> String {
        sheet.title ?? (sheet.page == nil ? entries.first { $0.id == sheet.spot }?.spot.name : nil) ?? sheet.page ?? sheet.spot
    }
}
