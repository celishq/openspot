import Foundation

extension SpotsModel {
    @discardableResult
    public func open(_ id: String) -> Bool {
        open(FlowSheet(spot: id))
    }

    public func openWorking(_ id: String) {
        asOnePress { _ = open(id) }
    }

    @discardableResult
    public func open(_ page: FlowSheet) -> Bool {
        guard entry(page.spot) != nil else { return false }
        afterShowing({ host.show() }) { [weak self] in
            guard let self else { return }
            endFlow()
            push(page)
        }
        return true
    }

    @discardableResult
    public func present(_ page: FlowSheet, from caller: String? = nil, replace: Bool = false) -> Bool {
        if caller != nil, page.route == nil, place(ofSheet: page.spot) == .window, !runs.floating.contains(page.spot) { askedWindows.insert(page.spot) }
        guard isShown, openSheetID != nil else {
            let row = isShown ? selectedEntry.flatMap { $0.spot.id == caller ? $0.id : nil } : nil
            return open(FlowSheet(spot: page.spot, route: page.route, title: page.title, source: row))
        }
        return push(page, replace: replace)
    }

    @discardableResult
    public func push(_ sheet: FlowSheet, replace: Bool = false) -> Bool {
        guard let spot = entry(sheet.spot)?.spot else { return false }
        if sheet.route == nil, place(ofSheet: sheet.spot) == .window {
            openWindow(sheet.spot)
            return true
        }
        if let route = sheet.route, !opensSheet(sheet.spot) {
            sheets[sheet.spot]?.pick(SpotItem(title: sheet.title ?? route, run: route))
            return true
        }
        if let route = sheet.route, !spot.takes(route: route) {
            toast(.failure("\(spot.name) takes no page \(route). Add \(route) to the pages of its spot.toml"))
            return true
        }
        let moves = isShown
        if !moves { host.show() }
        endEditing(moving: false)
        guard let route = sheet.route else {
            pushFirst(sheet.spot, moving: moves, title: sheet.title, source: sheet.source)
            return true
        }
        if openSheetID == nil { endFlow() }
        let next = FlowSheet(spot: sheet.spot, route: route, title: sheet.title ?? sheets[sheet.spot]?.list.all.first { $0.run == route }?.title)
        if replace, flow.current != nil { flow.replaceCurrent(with: next) } else { flow.push(next) }
        show(next, moving: moves)
        return true
    }

    @discardableResult
    public func pop(in id: String, all: Bool = false) -> Bool {
        guard openSheetID == id, flow.current?.spot == id else { return false }
        guard all else { return flow.behind != nil && popPage() }
        var start = flow.index
        while start > 0, flow.pages[start].route != nil, flow.pages[start - 1].spot == id { start -= 1 }
        return start < flow.index && popPage(steps: flow.index - start)
    }

    @discardableResult
    public func leave(_ id: String) -> Bool {
        if askedWindows.contains(id) {
            land(id)
            return true
        }
        guard openSheetID == id, flow.current?.spot == id else { return false }
        close(in: id)
        return true
    }

    private func close(in id: String) {
        guard flow.current?.spot == id else { return }
        var start = flow.index
        while start > 0, flow.pages[start].route != nil, flow.pages[start - 1].spot == id { start -= 1 }
        if start == 0 { closeSheet(moving: isShown) } else { popPage(steps: flow.index - start + 1) }
    }

    @discardableResult
    public func popPage(steps: Int = 1) -> Bool {
        guard openSheetID != nil, let page = flow.pop(steps: steps) else { return false }
        show(page, moving: isShown)
        return true
    }

    @discardableResult
    public func back(steps: Int = 1) -> Bool {
        asOnePress {
            guard openSheetID != nil, let page = flow.back(steps: steps) else { return false }
            show(page, moving: isShown)
            return true
        }
    }

    @discardableResult
    public func forward(steps: Int = 1) -> Bool {
        asOnePress {
            guard openSheetID != nil, let page = flow.forward(steps: steps) else { return false }
            show(page, moving: isShown)
            return true
        }
    }

    func move(_ move: FlowMove, in id: String) {
        guard openSheetID == id else { return }
        switch move {
        case .pop(true): pop(in: id, all: true)
        case .pop(false) where flow.behind == nil && flow.current?.spot == id: closeSheet(moving: isShown)
        case .pop: pop(in: id)
        case .close: close(in: id)
        case .push(let spot, let page, let title, let replace): push(FlowSheet(spot: spot ?? id, route: page, title: title), replace: replace)
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
            sheet.show(page)
            waitPush(moving: moving)
            return present(page.spot, moving: moving)
        }
        guard moving, sheet.route != page.route else {
            sheet.show(page)
            return showEdges()
        }
        pushIn { sheet.show(page) ? nil : sheet }
    }

    func endFlow() {
        for page in flow.pages where page.route != nil { sheets[page.spot]?.show(FlowSheet(spot: page.spot)) }
        flow.clear()
        showEdges()
    }

    func title(of sheet: FlowSheet) -> String {
        sheet.title ?? (sheet.route == nil ? entry(sheet.spot)?.spot.name : nil) ?? sheet.route ?? sheet.spot
    }
}
