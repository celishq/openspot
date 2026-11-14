import Foundation

/// The flow of the panel: a page or a spot that opens over the sheet that shows, and the keys that move back, forward
/// and to the grid.
extension SpotsModel {
    static let backKey = ActionKey(name: "[", isCommand: true)
    static let forwardKey = ActionKey(name: "]", isCommand: true)
    static let gridKey = ActionKey(name: "escape", isCommand: true)

    /// Opens a spot as a new flow, with nothing behind it: in the panel that shows, or else in the panel that it shows.
    /// Returns false when no spot has that ID.
    @discardableResult
    public func open(_ id: String) -> Bool {
        guard entries.contains(where: { $0.id == id }) else { return false }
        endFlow()
        return push(FlowSheet(spot: id))
    }

    /// Pushes a sheet over the flow that shows: in the panel that shows, or else in the panel that it shows. A page that the
    /// spot takes no `pages` line for moves nothing and says so, and a page of a spot with no sheet is the call
    /// `<spot> open <page>`. With `replace`, the sheet takes the place of the one that shows. Returns false when no spot has
    /// that ID.
    @discardableResult
    public func push(_ sheet: FlowSheet, replace: Bool = false) -> Bool {
        guard let spot = entries.first(where: { $0.id == sheet.spot })?.spot else { return false }
        if let page = sheet.page, !opensSheet(sheet.spot) {
            sheets[sheet.spot]?.pick(SpotItem(title: sheet.title ?? page, run: page))
            return true
        }
        if let page = sheet.page, !spot.takes(page: page) {
            host.notify("\(spot.name) takes no page \(page). Add pages=\(page) to its header")
            return true
        }
        let moves = isShown
        if !moves { host.show() }
        endEditing(moving: false)
        guard let page = sheet.page else {
            pushFirst(sheet.spot, moving: moves, title: sheet.title)
            return true
        }
        if openList == nil { endFlow() }
        let next = FlowSheet(spot: sheet.spot, page: page, title: sheet.title ?? sheets[sheet.spot]?.list.all.first { $0.run == page }?.title)
        if replace, flow.current != nil { flow.replaceCurrent(with: next) } else { flow.push(next) }
        show(next, moving: moves, from: 1)
        return true
    }

    /// Pops the sheet of a spot that shows: back to the sheet before it, a page of the spot or the sheet that pushed it.
    /// With `all`, back through its own pages to its first sheet. Returns false when it moves nothing, since a spot never
    /// closes the panel.
    @discardableResult
    public func pop(in id: String, all: Bool = false) -> Bool {
        guard openList == id, flow.current?.spot == id else { return false }
        guard all else { return flow.behind != nil && back() }
        var start = flow.index
        while start > 0, flow.pages[start].page != nil, flow.pages[start - 1].spot == id { start -= 1 }
        return start < flow.index && back(steps: flow.index - start)
    }

    /// Shows the sheet some steps before in the flow. Returns false when that many do not lie behind.
    @discardableResult
    public func back(steps: Int = 1) -> Bool {
        guard openList != nil, let page = flow.back(steps: steps) else { return false }
        show(page, moving: isShown, from: -1)
        return true
    }

    /// Shows the sheet after in the flow. Returns false when there is none.
    @discardableResult
    public func forward() -> Bool {
        guard openList != nil, let page = flow.forward() else { return false }
        show(page, moving: isShown, from: 1)
        return true
    }

    /// Moves the flow of the spot that shows, as a `push` or `pop` effect of its press asks (protocol: Pages). A spot that
    /// does not show moves nothing.
    func move(_ move: FlowMove, in id: String) {
        guard openList == id else { return }
        switch move {
        case .pop(let all): pop(in: id, all: all)
        case .push(let spot, let page, let title, let replace): push(FlowSheet(spot: spot ?? id, page: page, title: title), replace: replace)
        }
    }

    /// Whether the spot has a sheet that a push can show.
    func opensSheet(_ id: String) -> Bool {
        entries.first { $0.id == id }?.kind.opensSheet == true
    }

    /// Takes ⌘[, ⌘] and ⌘Esc while a sheet shows. Returns nil for any other key.
    func handleFlowKey(_ key: ActionKey) -> Bool? {
        switch key {
        case Self.backKey: back()
        case Self.forwardKey: forward()
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
