import Foundation

extension SpotsModel {
    @discardableResult
    public func open(_ id: String) -> Bool {
        guard entries.contains(where: { $0.id == id }) else { return false }
        endFlow()
        return push(FlowSheet(spot: id))
    }

    @discardableResult
    public func push(_ sheet: FlowSheet, replace: Bool = false) -> Bool {
        guard let spot = entries.first(where: { $0.id == sheet.spot })?.spot else { return false }
        if sheet.page == nil, place(ofSheet: sheet.spot) == .window {
            openWindow(sheet.spot)
            return true
        }
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

    @discardableResult
    public func pop(in id: String, all: Bool = false) -> Bool {
        guard openList == id, flow.current?.spot == id else { return false }
        guard all else { return flow.behind != nil && back() }
        var start = flow.index
        while start > 0, flow.pages[start].page != nil, flow.pages[start - 1].spot == id { start -= 1 }
        return start < flow.index && back(steps: flow.index - start)
    }

    @discardableResult
    public func back(steps: Int = 1) -> Bool {
        guard openList != nil, let page = flow.back(steps: steps) else { return false }
        show(page, moving: isShown, from: -1)
        return true
    }

    @discardableResult
    public func forward() -> Bool {
        guard openList != nil, let page = flow.forward() else { return false }
        show(page, moving: isShown, from: 1)
        return true
    }

    func move(_ move: FlowMove, in id: String) {
        guard openList == id else { return }
        switch move {
        case .pop(let all): pop(in: id, all: all)
        case .push(let spot, let page, let title, let replace): push(FlowSheet(spot: spot ?? id, page: page, title: title), replace: replace)
        }
    }

    func opensSheet(_ id: String) -> Bool {
        entries.first { $0.id == id }?.kind.opensSheet == true
    }

    func handleFlowKey(_ key: ActionKey) -> Bool? {
        switch FlowKey(key) {
        case .back: back()
        case .forward: forward()
        case .grid: closeList(moving: isShown)
        case nil: return nil
        }
        return true
    }

    private func show(_ page: FlowSheet, moving: Bool, from side: Double) {
        guard let sheet = sheets[page.spot] else {
            flow.remove(spot: page.spot)
            if let current = flow.current { show(current, moving: moving, from: side) } else { closeList(moving: moving) }
            return
        }
        guard openList == page.spot else {
            sheet.show(page: page.page)
            waitPush(from: moving ? side : nil)
            return present(page.spot, moving: moving)
        }
        guard moving, sheet.page != page.page else { return sheet.show(page: page.page) }
        pushIn(from: side) { sheet.show(page: page.page) }
    }

    func endFlow() {
        for page in flow.pages where page.page != nil { sheets[page.spot]?.show(page: nil) }
        flow.clear()
    }

    func title(of sheet: FlowSheet) -> String {
        sheet.title ?? (sheet.page == nil ? entries.first { $0.id == sheet.spot }?.spot.name : nil) ?? sheet.page ?? sheet.spot
    }
}
