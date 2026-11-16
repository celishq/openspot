import Foundation

extension SpotsModel {
    @discardableResult
    public func open(_ id: String) -> Bool {
        guard entry(id) != nil else { return false }
        endFlow()
        return push(FlowSheet(spot: id))
    }

    @discardableResult
    public func push(_ sheet: FlowSheet, replace: Bool = false) -> Bool {
        guard let spot = entry(sheet.spot)?.spot else { return false }
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
        if openSheetID == nil { endFlow() }
        let next = FlowSheet(spot: sheet.spot, page: page, title: sheet.title ?? sheets[sheet.spot]?.list.all.first { $0.run == page }?.title)
        if replace, flow.current != nil { flow.replaceCurrent(with: next) } else { flow.push(next) }
        show(next, moving: moves)
        return true
    }

    @discardableResult
    public func pop(in id: String, all: Bool = false) -> Bool {
        guard openSheetID == id, flow.current?.spot == id else { return false }
        if !all, flow.behind == nil, flow.current?.page == nil, id == runs.launchSheet {
            closeSheet(moving: isShown)
            return true
        }
        guard all else { return flow.behind != nil && popPage() }
        var start = flow.index
        while start > 0, flow.pages[start].page != nil, flow.pages[start - 1].spot == id { start -= 1 }
        return start < flow.index && popPage(steps: flow.index - start)
    }

    @discardableResult
    public func popPage(steps: Int = 1) -> Bool {
        guard openSheetID != nil, let page = flow.pop(steps: steps) else { return false }
        show(page, moving: isShown)
        return true
    }

    @discardableResult
    public func back(steps: Int = 1) -> Bool {
        guard openSheetID != nil, let page = flow.back(steps: steps) else { return false }
        show(page, moving: isShown)
        return true
    }

    @discardableResult
    public func forward(steps: Int = 1) -> Bool {
        guard openSheetID != nil, let page = flow.forward(steps: steps) else { return false }
        show(page, moving: isShown)
        return true
    }

    func move(_ move: FlowMove, in id: String) {
        guard openSheetID == id else { return }
        switch move {
        case .pop(let all): pop(in: id, all: all)
        case .push(let spot, let page, let title, let replace): push(FlowSheet(spot: spot ?? id, page: page, title: title), replace: replace)
        }
    }

    func opensSheet(_ id: String) -> Bool {
        entry(id)?.kind.opensSheet == true
    }

    func handleFlowKey(_ key: ActionKey) -> Bool? {
        switch FlowKey(key) {
        case .back: back()
        case .forward: forward()
        case .grid: closeSheet(moving: isShown)
        case nil: return nil
        }
        return true
    }

    func show(_ page: FlowSheet, moving: Bool) {
        guard !(moving && isStepping) else { return }
        guard let sheet = sheets[page.spot] else {
            flow.remove(spot: page.spot)
            if let current = flow.current { show(current, moving: moving) } else { closeSheet(moving: moving) }
            return
        }
        guard openSheetID == page.spot else {
            sheet.show(page: page.page)
            waitPush(moving: moving)
            return present(page.spot, moving: moving)
        }
        guard moving, sheet.page != page.page else {
            sheet.show(page: page.page)
            return showEdges()
        }
        pushIn { sheet.show(page: page.page) ? nil : sheet }
    }

    func endFlow() {
        for page in flow.pages where page.page != nil { sheets[page.spot]?.show(page: nil) }
        flow.clear()
        waitingPublish = nil
        showEdges()
    }

    func title(of sheet: FlowSheet) -> String {
        sheet.title ?? (sheet.page == nil ? entry(sheet.spot)?.spot.name : nil) ?? sheet.page ?? sheet.spot
    }
}
